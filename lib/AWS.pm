package AWS;
  use strict;
  use warnings;

  sub AccountId {
    return { Ref => 'AWS::AccountId' };
  }
  sub NotificationARNs {
    return { Ref => 'AWS::NotificationARNs' };
  }
  sub NoValue {
    return { Ref => 'AWS::NoValue' };
  }
  sub Region {
    return { Ref => 'AWS::Region' };
  }
  sub StackId {
    return { Ref => 'AWS::StackId' };
  }
  sub StackName {
    return { Ref => 'AWS::StackName' };
  }
1;
