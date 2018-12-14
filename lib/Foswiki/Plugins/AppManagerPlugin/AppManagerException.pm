package Foswiki::Plugins::AppManagerPlugin::AppManagerException;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(AppManagerException);

use JSON;

sub AppManagerException () { __PACKAGE__ };


sub new {
    my ($class, $message) = @_;
    my $this = {
        message => $message,
    };
    bless $this, $class;
    return $this;
}

1;
__END__
