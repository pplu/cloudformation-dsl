use CloudFormation::DSL::Traits;
# Load all Cfn objects from Cfn since we'll inherit from Cfn
use Cfn;
package CloudFormation::DSL::Object {
  use Moose;
  extends 'Cfn';

  has output_mappings => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
  );

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
      }
    }

    my $params_meta = $self->params->meta;
    @attrs = $params_meta->get_all_attributes;
    foreach my $param (@attrs) {
      if ($param->does('CloudFormation::DSL::AttributeTrait::StackParameter')) {
        my $type = $param->type_constraint->name;
        $self->addParameter($param->name, _moose_to_cfn_class($type));
      }
    }
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

  sub build {}
}
1;
