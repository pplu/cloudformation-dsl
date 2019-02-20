use CloudFormation::DSL::Traits;
# Load all Cfn objects from Cfn since we'll inherit from Cfn
use Cfn;

use Hash::AsObject;
use Moose::Util::TypeConstraints;

subtype 'ObjectifiedHash',
     as 'Hash::AsObject';

coerce 'ObjectifiedHash',
  from 'HashRef',
   via { Hash::AsObject->new($_) };

package CloudFormation::DSL::Object {
  use Moose;
  extends 'Cfn';

  has attachment_resolver => (
    is => 'ro',
    does => 'CloudFormation::DSL::AttachmentResolver',
  );

  has params => (
    is => 'ro',
    isa => 'ObjectifiedHash',
    coerce => 1,
    default => sub { Hash::AsObject->new({}) },
  );

  has stash => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
  );

  # Holds the mappings from logical output name, to the output name that will be sent and retrieved from cloudformation
  # This is done to support characters in the output names that cloudformation doesn't
  has output_mappings => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
  );

  # Helper to safely add things to stash
  sub add_to_stash {
    my ($self, $name, $value) = @_;
    die "An element is already in the stash with name $name" if (exists $self->stash->{$name});
    $self->stash->{ $name } = $value;
  }

  sub declaration_info {
    my ($self, $attribute) = @_;

    my $att = $self->meta->find_attribute_by_name($attribute);
    die "Can't find attribute $attribute" if (not defined $att);
    return $att->{ definition_context } // {};
  }

  # Small helper to map a Moose class (parameters have a type) to a CloudFormation type
  sub _moose_to_cfn_class {
    return {  
      Str => 'String',
      Int => 'Number',
      Num => 'Number',
    }->{ $_[0] } || 'String';
  }

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
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::StackParameter')) {
        my $type = $att->type_constraint->name;
        $self->addParameter($name, _moose_to_cfn_class($type));
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::Attachable')) {
	Moose->throw_error("Can't resolve attachments without an attachment_resolver") if (not defined $self->attachment_resolver);
        $self->params->$name($att->attachment_properties->{ Default }) if (defined $att->attachment_properties->{ Default });

	foreach my $parameter_name (keys %{ $att->provides }) {
          my $lookup_key = $att->provides->{ $parameter_name };
	  my $type = $att->type;
	  if (not defined $self->params->$parameter_name) {
            my $value = $self->attachment_resolver->resolve($name, $type, $lookup_key);
            $self->params->$parameter_name($value);
          }
        }
      } elsif ($att->does('CloudFormation::DSL::AttributeTrait::Parameter')) {
        if (not $att->does('CloudFormation::DSL::AttributeTrait::Attachable')) {
          $self->params->$name($self->$name->Default) if (defined $self->$name->Default);
        }
      }
    }
  }

  sub get_stackversion_from_metadata {
    my $self = shift;
    $self->Metadata('StackVersion');
  }

  before as_hashref => sub {
    my $self = shift;
    # This triggers any actions that the class
    # wants to do while building the cloudformation
    $self->build();
  };

  around addOutput => sub { 
    my ($orig, $self, $name, $output, @rest) = @_;
    my $new_name = $name;
    $new_name =~ s/\W//g;
    if (defined $self->Output($new_name)) {
      die "The output name clashed with an existing output name. Be aware that outputs are stripped of all non-alphanumeric chars before being declared";
    }
    if ($new_name ne $name) {
      $self->output_mappings->{ $new_name } = $name;
    }
    $self->$orig($new_name, $output, @rest);
  };

  use Sort::Topological qw//;

  sub creation_order {
    my ($self) = @_;

    my @result = Sort::Topological::toposort(sub {
      @{ $self->Resource($_[0])->dependencies }
    }, [ $self->ResourceList ]);

    return reverse @result;
  }

  sub build {}
}
1;
