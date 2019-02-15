use Fn;
use AWS;
package CloudFormation::DSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();

  use CCfnX::UserData;
  use CCfnX::DSL::Inheritance;
  use CloudFormation::DSL::Object;

  Moose::Exporter->setup_import_methods(
    with_meta => [qw/resource output mapping transform/],
    as_is     => [qw/Ref GetAtt Parameter CfString/],
    also      => 'Moose',
  );

  sub init_meta {
    shift;
    my %args = @_;
    return Moose->init_meta(%args, base_class => 'CloudFormation::DSL::Object');
  }

  sub transform {
    Moose->throw_error('Usage: transform name1, name2, ... , nameN;')
        if ( @_ < 1 );
    my ( $meta, @transforms ) = @_;

    if ( $meta->find_attribute_by_name('transform') ) {
      die "There is already a transform element in the template";
    }

    # Allow just one of this to be declared
    $meta->add_attribute(
      'transform_spec',
      is      => 'rw',
      isa     => 'ArrayRef[Str]',
      traits  => ['Transform'],
      lazy    => 1,
      default => sub { \@transforms },
    );

  }

  sub resource {
    # TODO: Adjust this error condition to better detect incorrect num of params passed
    Moose->throw_error('Usage: resource \'name\' => \'Type\', { key => value, ... }[, { DependsOn => ... }]')
        if (@_ != 4 and @_ != 5);
    my ( $meta, $name, $resource, $options, $extra ) = @_;

    $extra = {} if (not defined $extra);

    my %args = ();
    if (ref($options) eq 'CODE'){
      %args = &$options();
    } elsif (ref($options) eq 'HASH'){
      %args = %$options;
    };

    my $res_isa;
    if ($resource =~ m/^Custom::/){
      $res_isa = "Cfn::Resource::AWS::CloudFormation::CustomResource";
    } else {
      $res_isa = "Cfn::Resource::$resource";
    }

    my $default_coderef = resolve_resource_inheritance_dsl({
      meta => $meta,
      name => $name,
      resource => $resource,
      attr_family => 'CloudFormation::DSL::AttributeTrait::Resource',
      properties => \%args,
      extra => $extra,
    });

    $meta->add_attribute(
      $name,
      is => 'rw',
      isa => $res_isa,
      traits => [ 'Resource' ],
      lazy => 1,
      default => $default_coderef,
    );
  }

  sub output {
    Moose->throw_error('Usage: output \'name\' => Ref|GetAtt|{}[, { Condition => ... }]')
        if ( @_ lt 3 and @_ gt 5  );
    my ( $meta, $name, $options, $extra ) = @_;

    if ($meta->find_attribute_by_name($name)){
      die "Redeclared resource/output/condition/mapping $name";
    }

    $extra = {} if (not defined $extra);

    if (my ($att) = ($name =~ m/^\+(.*)/)) {
      $meta->add_attribute(
        $att,
        is => 'rw',
        isa => 'Cfn::Output',
        coerce => 1,
        traits => [ 'Output', 'PostOutput' ],
        lazy => 1,
        default => sub {
          return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Output')->coerce({
            Value => $options,
            %$extra }
          );
        },
      );
    } else {
      $meta->add_attribute(
        $name,
        is => 'rw',
        isa => 'Cfn::Output',
        coerce => 1,
        traits => [ 'Output' ],
        lazy => 1,
        default => sub {
          return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Output')->coerce({
            Value => $options,
            %$extra }
          );
        },
      );
    }
  }

  sub mapping {
    Moose->throw_error('Usage: mapping \'name\' => { key => value, ... }')
        if (@_ != 3);
    my ( $meta, $name, $options ) = @_;

    if ($meta->find_attribute_by_name($name)){
      die "Redeclared resource/output/condition/mapping $name";
    }

    my %args = ();
    if (ref($options) eq 'CODE'){
      %args = &$options();
    } elsif (ref($options) eq 'HASH'){
      %args = %$options;
    }

    $meta->add_attribute(
      $name,
      is => 'rw',
      isa => 'Cfn::Mapping',
      traits => [ 'Mapping' ],
      lazy => 1,
      default => sub {
        return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Mapping')->coerce({ %args });
      },
    );
  }

  sub Parameter {
    # When CCfnX::Shortcuts is attached to a class, it
    # overrides the Parameters method of Cfn without warning, making $cfn->Parameter('') return unexpected
    # things.
    #
    # This "if" is a hack to detect when Parameters is being called as a method ($_[0] is a ref)
    # or if it's being called as a shortcut
    #
    # TODO: decide how to fix the fact that Cfn has a Parameters method
    if (@_ > 1){
      my ($self, $key, $value) = @_;
      if (defined $value) {
        # Setter
        $self->Parameters({}) if (not defined $self->Parameters);
        $self->Parameters->{ $key } = $value;
      } else {
        # Getter
        return $self->Parameters->{ $key } if (defined $self->Parameters);
        return undef;
      }
    }
    my $param = shift;
    die "Must specify a parameter to read from" if (not defined $param);
    return CCfnX::DynamicValue->new(Value => sub {
      my $cfn = shift;
      Moose->throw_error("DynamicValue didn't get it's context") if (not defined $cfn);
      return $cfn->params->$param
    });
  }

  sub Ref {
    my $ref = shift;
    die "Ref expected a logical name to reference to" if (not defined $ref);
    return { Ref => $ref };
  }

  sub GetAtt {
    my ($ref, $property) = @_;
    die "GetAtt expected a logical name and a property name" if (not defined $ref or not defined $property);
    { 'Fn::GetAtt' => [ $ref, $property ] }
  }

  sub CfString {
    my $string = shift;
    return Cfn::DynamicValue->new(Value => sub {
      my @ctx = @_;
      CCfnX::UserData->new(text => $string)->as_hashref_joins(@ctx);
    });
  }

}
1;
