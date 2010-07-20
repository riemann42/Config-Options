package Config::Options;

# Copyright (c) 2007 Edward Allen III. All rights reserved.
#
## This program is free software; you can redistribute it and/or
## modify it under the terms of the Artistic License, distributed
## with Perl.
#

=pod

=head1 NAME

Config::Options - Module to provide a configuration hash with option to read from file.

=head1 SYNOPSIS

use Config::Options;

my $options = Config::Options->new({ verbose => 1, optionb => 2, mood => "sardonic" });

# Access option as a hash...
print "My mode is ", $options->{mood}, "\n";

# Merge a hash of options...
$options->options({ optionc => 5, style => "poor"});

# Merge options from file

$options->{optionfile} = $ENV{HOME} . "/.myoptions.conf";
$options->fromfile_perl();


=head1 AUTHOR

Edward Allen, ealleniii _at_ cpan _dot_ org

=head1 DESCRIPTION

The motivation for this module was to provide an option hash with a little bit of brains. It's
pretty simple and used mainly by other modules I have written.

=cut


use strict;
our $VERSION = 0.01;
our %OPTFILE_CACHE = ();

=pod

=over 4

=head1 METHODS

=item new()

my $options = Config::Options->new({hash_of_startup_options}); 

Create new options hash.  Pass it  a hash ref to start with.  Please note that this reference
is copied, not blessed.

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $self->options(@_);
}

=item clone()

my $newoptions = $options->clone();

Creates a clone of options object.

=cut

sub clone {
    my $self  = shift;
    my $clone = {%$self};
    bless $clone, ref $self;
    return $clone;
}

=item options()

my $optionsb = $options->options;     # Duplicates option file.  Not very usefull.
$options->options($hashref);          # Same as $options->merge($hashref);
my $value = $options->options("key")  # Return option value.
$options->options("key", "value")	  # Set an option.

This is a utility function for accessing options.  If passed a hashref, merges it.
If passed a scalar, returns the value.  If passed two scalars, sets the option. 

=cut

sub options {
    my $self   = shift;
    my $option = shift;
    if ( ref $option ) {
        return $self->merge($option);
    }
    elsif ($option) {
        my $value = shift;
        if ( defined $value ) {
            $self->{$option} = $value;
        }
        return $self->{$option};
    }
    return $self;
}

=item merge()

$options->merge($hashref); 

Merges values in $hashref and $options.

=cut

sub merge {
    my $self   = shift;
    my $option = shift;
    return unless ( ref $option );
    while ( my ( $k, $v ) = each %{$option} ) {
        $self->{$k} = $v;
    }
    return $self;
}

=item deepmerge()

$options->deepmerge($hashref); 

Same as merge, except when a value is a hash or array reference.  For example:

my $options = Config::Options->new({ moods => [ qw(happy sad angry) ] });
$options->deepmerge({ moods => [ qw(sardonic twisted) ] });

print join(" ", @{$options->{moods}}), "\n";

The above outputs:

happy sad angry sardonic twisted

=cut


sub deepmerge {
    my $self   = shift;
    my $option = shift;
    return unless ( ref $option );
    while ( my ( $k, $v ) = each %{$option} ) {
        if ( exists $self->{$k} ) {
            if ( ref $v eq "ARRAY" ) {
                push @{ $self->{$k} }, @{$v};
            }
            elsif ( ( ref $v eq "HASH" ) or ( ref $v eq ( ref $self ) ) ) {
                while ( my ( $vk, $vv ) = each %{$v} ) {
                    $self->{$k}->{$vk} = $vv;
                }
            }
            else {
                $self->{$k} = $v;
            }
        }
        else {
            $self->{$k} = $v;
        }
    }
    return $self;
}

=item fromfile_perl()

$options->fromfile_perl("/path/to/optionfile");

This is used to store options in a file.  The optionfile is actually a perl program that 
returns a hash.  By default uses option 'optionfile' as filename if none is passed.

=cut

sub fromfile_perl {
    my $self     = shift;
    my $filename = shift || $self->options("optionfile");
    my $files    = [];
    if ( ref $filename eq "ARRAY" ) {
        $files = $filename;
    }
    else {
        $files = [$filename];
    }
    foreach my $f ( @{$files} ) {
        if ( exists $OPTFILE_CACHE{$f} ) {
            $self->options( $OPTFILE_CACHE{$f} );
        }
        elsif ( -e $f ) {
			#print STDERR "Loading options from $f\n";
            local *IN;
            my $sub = "";
            open( IN, $f ) or die "Couldn't open option file $filename: $!";
            while (<IN>) {
                $sub .= $_;
            }
            close(IN);
            my $o = eval $sub;
            if ($@) { die "Can't process options file $: $@" }
            $self->options($o);
            $OPTFILE_CACHE{$f} = $o;
        }
    }
}


sub DESTROY {
}

1;
