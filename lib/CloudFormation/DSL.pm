use Fn;
use AWS;
package CloudFormation::DSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();

  our $VERSION = '0.01';
  # ABSTRACT: A DSL for building CloudFormation templates

  use Carp;
  use CCfnX::UserData;
  use CloudFormation::DSL::Inheritance;
  use CloudFormation::DSL::Object;
  use Regexp::Common qw(net);
  use LWP::Simple;
  use JSON::MaybeXS;
  use Scalar::Util qw(looks_like_number blessed);
  use DateTime::Format::Strptime qw( );

  our $ubuntu_release_table_url = 'https://cloud-images.ubuntu.com/locator/ec2/releasesTable';

  Moose::Exporter->setup_import_methods(
    with_meta => [ 'parameter', 'attachment', 'resource', 'output', 'condition', 
                   'mapping', 'metadata', 'stack_version', 'transform' ],
    as_is => [ qw/Ref ConditionRef GetAtt UserData CfString Parameter Attribute Json
                Tag ELBListener TCPELBListener SGRule SGEgressRule 
                GetASGStatus GetInstanceStatus FindUbuntuImage FindBaseImage SpecifyInSubClass/ ],
    also  => 'Moose',
  );

  # init_meta is used to make whoever uses CloudFormation::DSL to be a subclass
  # of CloudFormation::DSL::Object
  sub init_meta {
    shift;
    my %args = @_;
    return Moose->init_meta(%args, base_class => 'CloudFormation::DSL::Object');
  }

  sub _throw_if_attribute_duplicate {
    my ($meta, $attribute_name) = @_;

    if ($meta->find_attribute_by_name($attribute_name)) {
      die "Redeclared item \'$attribute_name\'";
    }
  }

  sub _get_definition_context {
    my $where = shift;
    my %context = Moose::Util::_caller_info(2);
    $context{context} = "$where declaration";
    $context{type} = 'DSL';
    return \%context;
  }

  sub transform {
    Moose->throw_error('Usage: transform name1, name2, ... , nameN;')
        if ( @_ < 1 );
    my ( $meta, @transforms ) = @_;

    _throw_if_attribute_duplicate($meta, 'transform');

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


  sub condition {
    Moose->throw_error('Usage: output \'name\' => Ref|GetAtt|{}')
        if (@_ != 3);
    my ( $meta, $name, $condition ) = @_;

    _throw_if_attribute_duplicate($meta, $name);

    $meta->add_attribute(
      $name,
      is => 'rw',
      isa => "Cfn::Value",
      traits => [ 'Condition' ],
      lazy => 1,
      coerce => 1,
      definition_context => _get_definition_context('condition'),
      default => sub {
        $condition;
      },
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
      definition_context => _get_definition_context('resource'),
    );
  }

  sub parameter {
    my ($meta, $name, $type, $options, $extra) = @_;

    _throw_if_attribute_duplicate($meta, $name);
    $extra = {}  unless(defined $extra);

    my %args = ();
    if (ref($options) eq 'CODE'){
      %args = &$options();
    } elsif (ref($options) eq 'HASH'){
      %args = %$options;
    }

    my $attr_traits = $extra->{InStack}
                    ? ['Parameter', 'StackParameter']
                    : ['Parameter'];

    $meta->add_attribute(
      $name,
      is  => 'rw',
      isa => "Cfn::Parameter",
      traits => $attr_traits,
      lazy => 1,
      default => sub {
        return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Parameter')->coerce({
          Type => $type,
          %args,
        });
      },
      definition_context => _get_definition_context('parameter'),
    );
  }

  sub _attachment_map {
    my $provides = shift;
    my @map;
    foreach my $key (keys %$provides) {
      my $info = {};

      if (substr($key,0,1) eq '-'){
        # Strip off the '-' in the attribute name
        my $attribute_name = $key;
	substr($attribute_name,0,1) = '';
	$info->{ attribute_name } = $attribute_name;
	$info->{ lookup_name } = $provides->{ $key };
	$info->{ in_stack } = 0;
      } else {
	$info->{ attribute_name } = $key;
	$info->{ lookup_name } = $provides->{ $key };
	$info->{ in_stack } = 1;
      }
      push @map, $info;
    }
    return \@map;
  }

  sub attachment {
    Moose->throw_error(
      'Usage: attachment \'name\' => \'type\', {provides_key => provides_value, ... }[, { Default => \'...\' }]'
    ) if (@_ < 2);
    my ($meta, $name, $type, $provides, $attachment_properties) = @_;

    _throw_if_attribute_duplicate($meta, $name);

    die "the provides parameter has to be a hashref" if (defined $provides and ref($provides) ne 'HASH');
    my $attachment_map = _attachment_map($provides);

    $attachment_properties = {} if (not defined $attachment_properties);
    die "the attachment_properties has to be a hashref" if (ref($attachment_properties) ne 'HASH');

    # Add the attachment
    $meta->add_attribute(
      $name,
      is     => 'rw',
      isa    => 'Str',
      type   => $type,
      traits => [ 'Parameter', 'Attachable' ],
      definition_context => _get_definition_context('attachment'),
      generates_params => [ map { $_->{ attribute_name } } @$attachment_map ],
      provides => { map { ($_->{ attribute_name } => $_->{ lookup_name }) } @$attachment_map },
      attachment_properties => $attachment_properties,
    );

    # Every attachment will declare that it provides some extra parameters in the provides
    # these will be converted in attributes. If they start with "-", then they will not be
    # StackParameters, that is they will not be accessible in CF via a Ref.
    foreach my $parameter (@$attachment_map) {
      _throw_if_attribute_duplicate($meta, $parameter->{ attribute_name });

      if ($parameter->{ in_stack }) {
        parameter($meta, $parameter->{ attribute_name }, 'String', {}, { InStack => 1 });
      } else {
        parameter($meta, $parameter->{ attribute_name }, 'String', {}, { });
      }
    }
  }

  sub output {
    Moose->throw_error('Usage: output \'name\' => Ref|GetAtt|{}[, { Condition => ... }]')
        if ( @_ lt 3 and @_ gt 5  );
    my ( $meta, $name, $options, $extra ) = @_;

    _throw_if_attribute_duplicate($meta, $name);

    $extra = {} if (not defined $extra);

    if (my ($att) = ($name =~ m/^\+(.*)/)) {
      $meta->add_attribute(
        $att,
        is => 'rw',
        isa => 'Cfn::Output',
        coerce => 1,
        traits => [ 'Output', 'PostOutput' ],
        lazy => 1,
        definition_context => _get_definition_context('output'),
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
        definition_context => _get_definition_context('output'),
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

    _throw_if_attribute_duplicate($meta, $name);

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
      definition_context => _get_definition_context('mapping'),
      default => sub {
        return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Mapping')->coerce({ %args });
      },
    );
  }

  sub metadata {
    Moose->throw_error('Usage: metadata \'name\' => {json-object}')
        if (@_ != 3);
    my ( $meta, $name, @options ) = @_;

    _throw_if_attribute_duplicate($meta, $name);

    if (my ($att) = ($name =~ m/^\+(.*)/)) {
      $meta->add_attribute(
        $att,
        is => 'rw',
        isa => 'Cfn::Value',
        coerce => 1,
        traits => [ 'Metadata' ],
        lazy => 1,
        definition_context => _get_definition_context('metadata'),
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
        definition_context => _get_definition_context('metadata'),
        default => sub {
          return Moose::Util::TypeConstraints::find_type_constraint('Cfn::Value')->coerce(@options);
        },
      );
    }
  }

  sub stack_version {
    Moose->throw_error('Usage: stack_version \'version\'')
        if (@_ != 2);
    my ( $meta, $version ) = @_;

    my $stack_version_attribute = 'StackVersion';

    _throw_if_attribute_duplicate($meta, $stack_version_attribute);

    $meta->add_attribute(
      $stack_version_attribute,
      is => 'rw',
      isa => 'Cfn::Value',
      coerce => 1,
      traits => [ 'Metadata' ],
      lazy => 1,
      definition_context => _get_definition_context('stack_version'),
      default => sub { return $version },
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
    if (blessed($_[0])){
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
      return $cfn->params->$param;
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

  sub SpecifyInSubClass {
    return Cfn::DynamicValue->new(Value => sub { die "You must specify a value" });
  }

  sub Tag {
    my ($tag_key, $tag_value, %rest) = @_;
    { Key => $tag_key, Value => $tag_value, %rest };
  }

  sub Ref {
    my $ref = shift;
    die "Ref expected a logical name to reference to" if (not defined $ref);
    return { Ref => $ref };
  }

  sub ConditionRef {
    my $condition = shift;
    die "Condition expected a logical name to reference to" if (not defined $condition);
    return { Condition => $condition };
  }

  sub Json {
    my $json = shift;
    my $result = eval { decode_json($json) };
    die "Error decoding Json: $@" if ($@);
    return $result;
  }

  sub GetAtt {
    my ($ref, $property) = @_;
    die "GetAtt expected a logical name and a property name" if (not defined $ref or not defined $property);
    { 'Fn::GetAtt' => [ $ref, $property ] }
  }

  sub ELBListener {
    my ($lbport, $lbprotocol, $instanceport, $instanceprotocol) = @_;
    die "no port for ELB listener passed" if (not defined $lbport);
    die "no protocol for ELB listener passed" if (not defined $lbprotocol);
    $instanceport     = $lbport     if (not defined $instanceport);
    $instanceprotocol = $lbprotocol if (not defined $instanceprotocol);

    return { InstancePort => $instanceport,
             InstanceProtocol => $instanceprotocol,
             LoadBalancerPort => $lbport,
             Protocol => $lbprotocol
           }
  }

  sub TCPELBListener {
    my ($lbport, $instanceport) = @_;
    return ELBListener($lbport, 'TCP', $instanceport);
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

  sub _extract_ami_from_uri {
      my $uri = shift || confess "Need URI";

      $uri =~ m{<a.*href.*>([\s\S]+?)</a>};
      return $1;
  }

  # NOTE: Only hvm:ebs-ssd supported!
  sub FindUbuntuImage {
      my $region = shift || confess "Need Region";
      my $version = shift || confess "Need Version";

      my $raw = get $ubuntu_release_table_url;
      die "Could not get Ubuntu release information" unless defined $raw;

      my $json = JSON->new->utf8->relaxed(1);
      my $info = $json->decode($raw)->{aaData};
      my @h = map {
        _extract_ami_from_uri($_->[6])
      } grep {
            $_->[0] eq $region &&
            $_->[1] eq $version &&
            $_->[3] eq 'amd64' &&
            $_->[4] eq 'hvm:ebs-ssd'
      } @$info;

      if (scalar @h > 1) {
          confess "Got more than a single AMI!";
      } elsif (scalar @h == 0) {
          confess "Did not find an image for '$version' in region '$region'";
      }

      return shift @h;

  }

  sub FindBaseImage {
    my $region  = shift;
    my @filters = @_;

    my @describe_images_filter = map {
      my ( $name, $value ) = split( '=', $_ );
      { Name => $name, Values => [$value] };
    } @filters;

    my $ec2 = Paws->service( 'EC2', region => $region );
    my @amis = @{ $ec2->DescribeImages(
        Filters => \@describe_images_filter,
    )->Images };

    # print "\n\n Unsorted list of amis: \n";
    # foreach my $ami (@amis) { printf( "%s - %s\n", $ami->ImageId, $ami->CreationDate ) }

    my @sorted_amis = sort {

      my $format = DateTime::Format::Strptime->new(
        pattern   => '%Y-%m-%dT%T',
        time_zone => 'UTC',
        on_error  => 'croak',
        strict    => 1,
      );
      my $dta = $format->parse_datetime( $a->CreationDate );
      my $dtb = $format->parse_datetime( $b->CreationDate );

      # Reversed sort so the latest one ends up in position 0
      $dtb <=> $dta
    } @amis;

    # print "\n\n Sorted list of amis: \n";
    # foreach my $ami (@sorted_amis) { printf( "%s - %s\n", $ami->ImageId, $ami->CreationDate ) }

    my $ami = $sorted_amis[0];

    die "FindBaseImage: Couldn't find any image that match the specified filters\n" if not defined $ami;
    warn sprintf( "FindBaseImage: using '%s' with ID '%s' as the base image (created at %s)\n", $ami->Name, $ami->ImageId, $ami->CreationDate );
    return $ami->ImageId;
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

  sub GetASGStatus {
  }

  sub GetInstanceStatus {
  }

}
1;
