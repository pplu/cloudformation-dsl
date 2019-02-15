use Fn;
use AWS;
# Load all Cfn objects from Cfn
use Cfn;
use CloudFormation::DSL::Traits;
package CloudFormation::DSL::Object {
  use Moose;
  extends 'Cfn';

  # When the object is instanced, we want any of the attributes declared in the class to be created
  # That means that attributes with Resource, Output, Condition or Output roles are "attached" to the object
  # This is done to make the newly created object represent all that the user has declared "in the class" when
  # they call ->new
  # All these attributes are normally created with CCfnX::Shortcuts, but can really be created by hand (not recommended)
  sub BUILD {
    my $self = shift;
    my $class_meta = $self->meta;
    my @attrs = $class_meta->get_all_attributes;
    foreach my $att (@attrs) {
      my $name = $att->name;
      if ($att->does('CloudFormation::DSL::AttributeTrait::Resource')) {
        $self->addResource($name, $self->$name);
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::Output')){
        $self->addOutput($name, $self->$name);
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::Condition')){
        $self->addCondition($name, $self->$name);
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::Mapping')){
        $self->addMapping($name, $self->$name);
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::Metadata')){
        $self->addMetadata($name, $self->$name);
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::Transform')){
        $self->addTransform($name, $self->$name);
      }
    }

    #my $params_meta = $self->params->meta;
    #@attrs = $params_meta->get_all_attributes;
    #foreach my $param (@attrs) {
    #  if ($param->does('CloudFormation::DSL::AttributeTrait::StackParameter')) {
    #    my $type = $param->type_constraint->name;
    #    $self->addParameter($param->name, _moose_to_cfn_class($type));
    #  }
    #}
  }

}
package CloudFormation::DSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();

  use CCfnX::DSL::Inheritance;

  Moose::Exporter->setup_import_methods(
    with_meta => [qw/resource/],
    as_is     => [qw/Parameter/],
    also      => 'Moose',
  );

  sub init_meta {
    shift;
    my %args = @_;
    return Moose->init_meta(%args, base_class => 'CloudFormation::DSL::Object');
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

}
1;
