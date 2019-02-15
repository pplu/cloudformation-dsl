package CloudFormation::DSL::AttributeTrait::RefValue {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('RefValue');
}

package CloudFormation::DSL::AttributeTrait::StackParameter {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('StackParameter');
}

package CloudFormation::DSL::AttributeTrait::Resource {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Resource');
}

package CloudFormation::DSL::AttributeTrait::Metadata {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Metadata');
}

package CloudFormation::DSL::AttributeTrait::Condition {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Condition');
}

package CloudFormation::DSL::AttributeTrait::Output {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Output');
}

package CloudFormation::DSL::AttributeTrait::Mapping {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Mapping');
}

package CloudFormation::DSL::AttributeTrait::Transform {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Transform');
}

package CloudFormation::DSL::AttributeTrait::PostOutput {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('PostOutput');
}

package CloudFormation::DSL::AttributeTrait::Attached {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Attached');
}

package CloudFormation::DSL::AttributeTrait::Attachable {
  use Moose::Role;
  Moose::Util::meta_attribute_alias('Attachable');
  has type => (is => 'ro', isa => 'Str', required => 1);
  has generates_params => (is => 'ro', isa => 'ArrayRef[Str]', required => 1);

  sub get_info {
    my ($self, $name, $key) = @_;
    die "Not implemented";
  }
}

1;
