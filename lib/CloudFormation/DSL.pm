use Fn;
use AWS;
package CloudFormation::DSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();

  use Carp;
  use CCfnX::UserData;
  use CCfnX::DSL::Inheritance;
  use CloudFormation::DSL::Object;
  use Regexp::Common qw(net);
  use Scalar::Util qw(looks_like_number);

  Moose::Exporter->setup_import_methods(
    with_meta => [qw/resource output mapping metadata transform/],
    as_is     => [qw/Ref GetAtt Parameter CfString UserData Attribute SGEgressRule SGRule/],
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

  sub metadata {
    Moose->throw_error('Usage: metadata \'name\' => {json-object}')
        if (@_ != 3);
    my ( $meta, $name, @options ) = @_;

    if (my ($att) = ($name =~ m/^\+(.*)/)) {
      $meta->add_attribute(
        $att,
        is => 'rw',
        isa => 'Cfn::Value',
        coerce => 1,
        traits => [ 'Metadata' ],
        lazy => 1,
        default => sub {
          return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Value')->coerce(@options);
        },
      );
    } else {
      $meta->add_attribute(
        $name,
        is => 'rw',
        isa => 'Cfn::Value',
        coerce => 1,
        traits => [ 'Metadata' ],
        lazy => 1,
        default => sub {
          return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Value')->coerce(@options);
        },
      );
    }
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
    return Cfn::DynamicValue->new(Value => sub {
      my $cfn = shift;
      Moose->throw_error("DynamicValue didn't get it's context") if (not defined $cfn);
      return $cfn->params->$param
    });
  }

  sub Attribute {
    my $path = shift;
    my ($attribute, $method, $rest) = split /\./, $path;
    croak "Don't understand attributes with more than two path elements" if (defined $rest);
    croak "Must specify an attribute read from" if (not defined $attribute);
    if (not defined $method) {
      return Cfn::DynamicValue->new(Value => sub { return $_[0]->$attribute });
    } else {
      return Cfn::DynamicValue->new(Value => sub { return $_[0]->$attribute->$method });
    }
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

  # Creates a rule for a security group:
  # IF port is a number, it opens just that port
  # IF port is a range: number-number, it opens that port range
  # to: where to open the rule to. If this looks like a CIDR, it will populate CidrIP in the rule,
  #     else, it will populate SourceSecurityGroupId. (This means that you can't use this shortcut
  #     to open a SG to a Ref(...) in a parameter, for example).
  # proto: if specified, uses that protocol. If not, TCP by default
  sub SGRule {
    my ($port, $to, $proto_or_desc, $desc) = @_;
    my $proto;

    if (defined($proto_or_desc)) {
        if ($proto_or_desc eq 'tcp'
                or $proto_or_desc eq 'udp'
                or $proto_or_desc eq 'icmp'
                or looks_like_number($proto_or_desc)) {
            $proto = $proto_or_desc;
        } else {
            $proto = 'tcp';
            $desc  = $proto_or_desc;
        }
    }

    my ($from_port, $to_port);
    if ($port =~ m/\-/) {
      if ($port eq '-1') {
        ($from_port, $to_port) = (-1, -1);
      } else {
        ($from_port, $to_port) = split /\-/, $port, 2;
      }
    } else {
      ($from_port, $to_port) = ($port, $port);
    }

    $proto = 'tcp' if (not defined $proto);
    my $rule = { IpProtocol => $proto, FromPort => $from_port, ToPort => $to_port};
    $rule->{ Description } = $desc if (defined $desc);

    my $key;
    # Rules to detect when we're trying to open to a CIDR

    # If $to is a reference, it means that it is either:
    #   - A CloudDeploy Ref of another resource
    #   - A CCfnX::DynamicValue object (usually coming from a Parameter())
    # In both cases, it ends up pointing to a SG identifier.
    # If $to is an IP address, it will come in form of a string (scalar)
    # hence falling back to a SSGroupId
    unless (ref($to)) {
        $key = 'CidrIp' if ($to =~ m/$RE{net}{IPv4}/);
        $key = 'CidrIpv6' if ($to =~ m/$RE{net}{IPv6}/);
    }

    # Fallback to SSGroupId
    $key = 'SourceSecurityGroupId' if (not defined $key);

    $rule->{ $key } = $to;

    return $rule;
  }

  sub SGEgressRule {
    my ($port, $to, $proto_or_desc, $desc) = @_;
    my $proto;

    if (defined($proto_or_desc)) {
        if ($proto_or_desc eq 'tcp'
                or $proto_or_desc eq 'udp'
                or $proto_or_desc eq 'icmp'
                or looks_like_number($proto_or_desc)) {
            $proto = $proto_or_desc;
        } else {
            $proto = 'tcp';
            $desc  = $proto_or_desc;
        }
    }

    my ($from_port, $to_port);
    if ($port =~ m/\-/) {
      if ($port eq '-1') {
        ($from_port, $to_port) = (-1, -1);
      } else {
        ($from_port, $to_port) = split /\-/, $port, 2;
      }
    } else {
      ($from_port, $to_port) = ($port, $port);
    }

    $proto = 'tcp' if (not defined $proto);
    my $rule = { IpProtocol => $proto, FromPort => $from_port, ToPort => $to_port};
    $rule->{ Description } = $desc if (defined $desc);

    my $key;
    # Rules to detect when we're trying to open to a CIDR

    # If $to is a reference, it means that it is either:
    #   - A CloudDeploy Ref of another resource
    #   - A CCfnX::DynamicValue object (usually coming from a Parameter())
    # In both cases, it ends up pointing to a SG identifier.
    # If $to is an IP address, it will come in form of a string (scalar)
    # hence falling back to a SSGroupId
    unless (ref($to)) {
        $key = 'CidrIp' if ($to =~ m/$RE{net}{IPv4}/);
        $key = 'CidrIpv6' if ($to =~ m/$RE{net}{IPv6}/);
    }

    # Fallback to SSGroupId
    $key = 'DestinationSecurityGroupId' if (not defined $key);

    $rule->{ $key } = $to;
    return $rule;
  }

  sub UserData {
    my @args = @_;
    return Cfn::DynamicValue->new(Value => sub {
      my @ctx = @_;
      CCfnX::UserData->new(text => $args[0])->as_hashref(@ctx);
    });
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
