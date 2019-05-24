#!/usr/bin/perl -w
use strict;
BEGIN { unshift @INC, split(/:/, $ENV{FOSWIKI_LIBS}); }
use Foswiki::Contrib::Build;

package AppManagerBuild;
our @ISA = qw(Foswiki::Contrib::Build);

sub new {
  my $class = shift;
  return bless($class->SUPER::new( "AppManagerPlugin" ), $class);
}

sub target_build {
  my $this = shift;
  $this->_installDeps();
}

sub target_compress {}

sub _installDeps {
  my $this = shift;

  local $| = 1;
  print $this->sys_action( qw(yarn) );
  print $this->sys_action( qw(yarn build) );
  # note: on error BuildContrib will swallow up STDOUT, so we wouldn't see which tests failed
  print $this->sys_action( qw(yarn lint 1>&2) );
  # print $this->sys_action( qw(yarn test:unit 1>&2) );
}

my $build = AppManagerBuild->new();
$build->build($build->{target});
