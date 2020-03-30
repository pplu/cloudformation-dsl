use Fn;
use AWS;
package CloudFormation::DSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();
  use true ();

  our $VERSION = '0.01';
  # ABSTRACT: A DSL for building CloudFormation templates

  use Carp;
  use CCfnX::UserData;
  use CCfnX::DSL::Inheritance;
  use CloudFormation::DSL::Object;
  use Regexp::Common qw(net);
  use LWP::Simple;
  use JSON::MaybeXS;
  use Scalar::Util qw(looks_like_number blessed);
  use DateTime::Format::Strptime qw( );

  our $ubuntu_release_table_url = 'https://cloud-images.ubuntu.com/locator/ec2/releasesTable';

  # import method is used to export functions provided by
  # packages that doesn't uses Moose::Exporter 
  sub import {
    my ($import) = Moose::Exporter->build_import_methods(
      install => [ 'unimport' ],
      with_meta => [ 'parameter', 'attachment', 'resource', 'output', 'condition', 
                    'mapping', 'metadata', 'stack_version', 'transform' ],
      as_is => [ qw/Ref ConditionRef GetAtt UserData CfString Parameter Attribute Json
                  Tag ELBListener TCPELBListener SGRule SGEgressRule 
                  GetASGStatus GetInstanceStatus FindUbuntuImage FindBaseImage SpecifyInSubClass/ ],
      also  => 'Moose',
    );
    true->import();

    goto &$import;
  }

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
    return Fn::GetAtt(@_);
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
### main pod documentation begin ###

=encoding UTF-8

=head1 NAME

CloudFormation::DSL - A Domain Specific Language for creating CloudFormation templates

=head1 SYNOPSIS

  package MyStack {
    use CloudFormation::DSL;

    resource Instance1 => 'AWS::EC2::Instance', {
      ImageId => 'ami-12345',
    };

    output IP => GetAtt('Instance1', 'PublicIp');
  }

  my $s1 = MyStack->new;
  say "Resource Count: " . $s1->ResourceCount;
  print $s1->as_hashref;

=head1 DESCRIPTION

CloudFormation is a great AWS service for automating infrastructure creation. You can get a better
grasp of what CloudFormation does and tries to solve here: L<https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html>

CloudFormation::DSL is a "framework" for writing CloudFormation and addressing some of its shortcomings.
It lets you express CloudFormation templates in an easier fashion, with a more forgiving syntax 
than the standard JSON or YAML syntaxes that CloudFormation supports. It also eases authoring some 
complex CloudFormation patterns.

You can think of it as a preprocessor that generates CloudFormation documents.

CloudFormation::DSL builds on the idea that the information in a CloudFormation template can be
expressed as a class. After all, a class is a template for an object! Since we represent templates 
as classes, we can instance those classes, manipulate and query them. An instance of a class has
an C<as_json> method that once called generates the CloudFormation document that can be sent to
the CloudFormation service.

CloudFormation::DSL builds upon existing layers:

L<Cfn>: Each C<CloudDeploy::DSL> class is a Cfn subclass. This means that the object model that 
Cfn provides is accessible from C<CloudDeploy::DSL>.

L<Moose> and L<Perl>: C<CloudDeploy::DSL> builds upon Moose's (An Object Orientation framework for Perl)
and Perl's ability to add syntax to the language. This let's us declare keywords like C<resource> 
or C<paramter> so you can write your CloudFormation templates in a faster way. This is just an implementation
detail: you don't need to know Moose or Perl to use C<CloudFormation::DSL>.

CloudFormation::DSL brings you full object orientation to your CloudFormation template authoring: you
can create base classes, inherit, override and specialize.

Enough chit-chat: let's see the action:

=head1 Writing a class

Start a file named `MyCfn.pm`

  package MyCfn {
    use CloudFormation::DSL;
  }
  1;

You now have a class that represents a template without resources. Now we'll add stuff with
the following keywords:

=head2 resource Name => 'TYPE', { ... Properties ... };

  package MyCfn {
    use CloudFormation::DSL;

    resource User1 => 'AWS::IAM::User', {
      Path => "/",
    };
  }

The resource keyword declares a CloudFormation resource of type C<TYPE>. The supported types
are available in the C<Cfn::Resource> namespace. This piece of code generates the following
CloudFormation:

  {
    "Resources": {
      "User1": {
        "Type": "AWS::IAM::User",
	"Properties": {
          "Path": "/"
	}
      }
    }
  }

Note a couple of things that the DSL is doing for us:

C<User1> doesn't have to be quoted. Perls "fat comma" automatically quotes it for us!

You could write:

  resource 'User1' => 'AWS::IAM::User', { ... };

if you wanted. You could also use double quotes:

  resource "User1" => 'AWS::IAM::User', { ... };

You actually need to do this if the resource name has special characters. 

Note that we specify the properties just after the object in a Key / Value fashion.
We use Perls Hashrefs to represent these Key/Value structures. The Keys are the same
keys that we would use in the C<"Properties"> object in a CloudFormation template. The
values can be Perl strings C<"myvalue">, Perl numbers C<42>, bareword booleans C<true> 
or C<false> and also CloudFormation functions like C<{ Ref => 'LogicalId' }> and 
C<{ 'Fn::GetAtt' =>  [ 'LogicalId', 'AttributeName' ] }> as Perl HashRefs. If you think 
this is typing too much, please read the "shortcuts" section. You don't have to type
C<"Properties">, and these go first, since 99% of the time we write resources, we
write their properties.

Note that in HashRefs we can leave trailing commas:

  { Path => '/', }

is valid, while in JSON

  { "Path": "/", }

isn't valid.

The DSL is also helping us assuring that AWS::IAM::User is a valid resource type. If we
don't use a supported resource type, we will get an error. This is also true for its
properties. The C<AWS::IAM::User> object has a property called C<Path>. If we had a
typo in the C<Path> property, we would get an error. If we didn't define a required property
we get an error. If we used a wrong value: we get an error.

=head2 resource Name => 'TYPE', { ... Properties ... }, { ... Resource Attributes ... }

If we want to configure resource properties like C<DependsOn> or C<DeletionPolicy>
we can do so passing a fourth element to our C<resource> statement:

  resource "User1" => 'AWS::IAM::User', { ... }, { DeletionPolicy => 'Retain' };

The DSL will verify that the DeletionPolicy is a permitted value in CloudFormation.

=head2 output Name => ...;

This will declare an output in our CloudFormation template.

  package MyCfn {
    use CloudFormation::DSL;

    resource User1 => 'AWS::IAM::User', {
      Path => "/"
    };

    output IAMUser => Ref('User1');
  }

Note that the name of the output doesn't need to be quoted (just like in with the
C<resource> keyword. The value for an output is the same ones that CloudFormation supports.
In the example we're using a shortcut to specify a CloudFormation Ref function. We could
have wrote:

  output IAMUser => { Ref => 'User1' };

The two are equivalent to the following CloudFormation JSON:

  {
    "Outputs": {
      "IAMUser": {
        "Value": { "Ref": "User1" }
      }
    }
  }

=head2 output Name => ..., { ... Output properties ... };

We can also specify extra properties for the output C<Description>,

  output IAMUser => { Ref => 'User1' }, {
    Description => 'The name of the IAM user',
  };

Will generate:

  {
    "Outputs": {
      "IAMUser": {
        "Value": { "Ref": "User1" },
        "Description": "The name of the IAM user"
      }
    }
  }

=head2 parameter Name => 'TYPE', { ... Properties ... }

The C<parameter> keyword adds a CloudFormation parameter to the template.

  parameter IAMPath => 'String',

Generates:

  {
    "Parameters": {
      "IAMPath": {
        "Type": "String"
      }
    }
  }

=head2 parameter Name => 'TYPE', { ... Properties ... }

We can also specify parameter properties like C<Default>,
C<NoEcho>, C<MaxLength>, etc.

  parameter IAMPath => 'String', {
    Default => '/',
    MazLength => 32,
  };

Generates:

  {
    "Parameters": {
      "IAMPath": {
        "Type": "String",
	"Default": "/",
	"MaxLength": 32
      }
    }
  }

=head2 condition Name => ...;

Adds a condition to the template

=head2 mapping Name => { }

Adds a CloudFormation mapping with a specific name

=head2 metadata

Adds a metadata key to the template

=head2 transform

Adds a transform to the template

=head2 stack_version

=head1 Shortcuts

=head2 Ref('LogicalId')

is a shorthand way to write C<{ Ref => 'LogicalId' }>

It writes C<{"Ref":"LogicalId"}> in the CloudFormation template.

=head2 GetAtt('LogicalId', 'AttributeName')

is a shorthand way to write

=head2 Parameter('ParameterName')

is a shorthand way of referencing a parameter that doesn't get passed to CloudFormation. 

=head2 Tag($key, $value)

is a shorhand way of writing the values that most C<Tag> attributes of resources expect:

  Tag('Owner', 'me')

gets converted to

  { "Key": "Owner", "Value": "me" }

in CloudFormation

An example of usage would be:

  resource Subnet1 => 'AWS::EC2::Subnet', {
    VpcId => Ref('Vpc'),
    CidrBlock => '10.0.0.0/24',
    Tags => [ Tag('Owner', 'me'), Tag('BU', 'sales') ],
  };

=head2 Attribute('AttributeName')

is a shorthand way of referencing an instance attribute. This is for advanced use. See
the "Instance Attributes" section.

=head2 UserData($string)

is a shorthand way to import the contents of a file in "UserData" format:
  
=head3 TieFighters

Tiefighters are sequences of C<#-#...#-#> that can be found inside the files
that the UserData keyword converts to the

=head4 #-#LogicalId#-#

Inserts a Ref('LogicalId')

=head4 #-#LogicalId->Attribute#-#

Inserts a GetAtt('LogicalId', 'Attribute') 

=head4 #-#Parameter(ParamName)#-#

Inserts a Parameter

=head4 #-#Attribute(ParamName)#-#

Inserts an Attribute value

=head2 CfString($string)

is a shorthand way to write a string that has gets tiefighters interpreted

=head2 Json($json_string)

will convert a JSON string into a HashRef

=head1 Networking shortcuts

=head2 ELBListener($lbport, $lbprotocol[, $instance_port[, $instance_protocol]])

is a shorthand way of writing an ELB Listener. It can be used in many ways:

C<ELBListener(80, 'HTTP')> will forward traffic from port 80 of the ELB to port 80 on the backends

C<ELBListener(80, 'HTTP', 3000)> will forward traffic from port 80 of the ELB to port 3000 on the 
backends

C<ELBListener(443, 'HTTPS', 5000, 'HTTP') will do SSL offloading on the ELB, forwarding to port 
5000 HTTP on the backends

=head2 TCPELBListener($lbport[, $instance_port])

=head2 SGRule($port, $to, $desc)

=head2 SGRule($port, $to, $proto, $desc)

=head2 SGEgressRule

=head1 Getting the most out of the DSL

=head1 Inheritance

You can use inheritance primitives to structure your infrastructure into reusable modules

  package MyBaseClass {
    use CloudFormation::DSL;

    resource I1 => 'AWS::EC2::Instance', {
      ImageId => SpecifyInSubClass,
      SecurityGroups => [ Ref('SG' ],
    };
    resource SG => 'AWS::EC2::SecurityGroup, {
      ...
    };
  }
  package SubClass1 {
    use CloudFormation::DSL;
    extends 'MyBaseClass';
    resource I1 => 'AWS::IAM::User', {
      ImageId => 'ami-XXXX',
    };
  }

=head2 SpecifyInSubClass

Use C<SpecifyInSubClass> to force the user to overwrite this value in a subclass:

  package MyBase {
    use CloudFormation::DSL;

    resource User1 => 'AWS::IAM::User', {
      Path => SpecifyInSubclass,
    };
  }

If MyBase is instanced, an error will be thrown. The value can be overwritten in 
subclasses:

  package MySubClass {
    use CloudFormation::DSL;
    extends 'MyBase';

    resource '+User1' => 'AWS::IAM::User', {
      Path => '/',
    };
  }

=head1 Attachments

=head2 attachment 

Adds an attachment to the template

=head1 Extending the DSL

=head1 Instance Attributes

=head1 SEE ALSO

L<Cfn>

L<https://docs.aws.amazon.com/es_es/AWSCloudFormation/latest/UserGuide/Welcome.html>

=head1 AUTHOR

    Jose Luis Martinez
    CAPSiDE
    jlmartinez@capside.com

=head1 Contributions

Thanks to Sergi Pruneda, Miquel Ruiz, Luis Alberto Gimenez, Eleatzar Colomer, Oriol Soriano, 
Roi Vazquez for years of work on this module.

=head1 BUGS and SOURCE

The source code is located here: L<https://github.com/pplu/cloudformation-dsl>

Please report bugs to: L<https://github.com/pplu/cfn-perl/cloudformation-dsl>

=head1 COPYRIGHT and LICENSE

Copyright (c) 2013 by CAPSiDE
This code is distributed under the Apache 2 License. The full text of the 
license can be found in the LICENSE file included with this module.

=cut
