package Fn;
  use strict;
  use warnings;

  sub Join {
    my ($with, @args) = @_;
    return { 'Fn::Join' => [ $with, [ @args ] ] };
  }

  sub ImportValue {
    my ($value) = @_;
    return { "Fn::ImportValue" => $value };
  }

  sub Split {
    my ($delimiter, $string) = @_;
    return { "Fn::Split" => [ $delimiter, $string ] };
  }

  sub FindInMap {
    my ($map_name, @keys) = @_;
    return { "Fn::FindInMap" => [ $map_name, @keys ] };
  }

  sub Sub {
    my ($string, @vars) = @_;
    if (@vars) {
      return { "Fn::Sub" => [ $string, { @vars } ] };
    } else {
      return { "Fn::Sub" => $string };
    }
  }

  sub Base64 {
    my ($what) = @_;
    return { "Fn::Base64" => $what };
  }

  sub GetAZs {
    return { "Fn::GetAZs" => "" };
  }

  sub Select {
    my ($index, $array) = @_;
    return { "Fn::Select" => [ $index, $array ] };
  }

  sub Equals {
    my $value1 = shift;
    my $value2 = shift;
    die "Fn::Equals only admits two parameters" if (@_ > 0);
    return { "Fn::Equals" => [ $value1, $value2 ] };
  }

  sub Not {
    my $condition = shift;
    die "Fn::Equals only admits one parameter" if (@_ > 0);
    return { "Fn::Not" => [ $condition ] }
  }

  sub If {
    my $condition_name = shift;
    my $value_true = shift;
    my $value_false = shift;
    die "Fn::If only admits three parameters" if (@_ > 0);
    return { "Fn::If" => [ $condition_name, $value_true, $value_false ] };
  }

  sub Or {
    my @conditions = @_;
    return { 'Fn::Or' => [ @conditions ] };
  }

  # Generates { "Fn::Transform" : { "Name" : macro name, "Parameters" : {key : value, ... } } }
  sub Transform {
    my ($macro_name, $params) = @_;

    return { 'Fn::Transform' => {
      name => $macro_name,
      parameters => $params,
    }}
  };

  sub Cidr {
    my ($ipblock, $count, $sizemask) = @_;
    if (defined $sizemask) {
      return { 'Fn::Cidr' => [ $ipblock, $count, $sizemask ] };
    } else {
      return { 'Fn::Cidr' => [ $ipblock, $count ] };
    }
  }

1;

