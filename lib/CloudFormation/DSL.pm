use Fn;
use AWS;
package CloudFormation::DSL::Object {
  use Moose;
  extends 'Cfn';

}
package CloudFormation::DSL {
  use Moose ();
  use Moose::Exporter;
  use Moose::Util::MetaRole ();

  Moose::Exporter->setup_import_methods(
    with_meta => [qw//],
    also      => 'Moose',
  );


}
1;
