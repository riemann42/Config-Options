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
use Data::Dumper;
use Carp;

our $VERSION = 0.02;
our %OPTFILE_CACHE = ();

=pod

=over 4

=head1 METHODS

=item new()

Create new options hash.  Pass it  a hash ref to start with.  Please note that this reference
is copied, not blessed.

	my $options = Config::Options->new({hash_of_startup_options}); 

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    $self->options(@_);
}

=item clone()

Creates a clone of options object.

	my $newoptions = $options->clone();

=cut

sub clone {
    my $self  = shift;
    my $clone = {%$self};
    bless $clone, ref $self;
    return $clone;
}

=item options()

This is a utility function for accessing options.  If passed a hashref, merges it.
If passed a scalar, returns the value.  If passed two scalars, sets the option. 

	my $optionsb = $options->options;     # Duplicates option file.  Not very usefull.
	$options->options($hashref);          # Same as $options->merge($hashref);
	my $value = $options->options("key")  # Return option value.
	$options->options("key", "value")	  # Set an option.

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

Takes a hashref as argument and merges with current options.

	$options->merge($hashref); 


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

=pod

=item tofile_perl()

This is used to store options to a file. The file is actually a perl program that 
returns a hash.  By default uses option 'optionfile' as filename, or value passed as argument.

If 'optionfile' is an array, then uses LAST option in array as default. 

	$options->tofile_perl("/path/to/optionfile");

=cut

sub tofile_perl {
    my $self     = shift;
    my $filename = shift || $self->options("optionfile");
	my $file;
    if ( ref $filename ) {
        $file = $filename->[-1];
    }
	else {
		$file = $filename;
	}
	local *OUT;
	open (OUT, ">", $file) or croak "Can't open option file: $file for write: $!";
	my $data = $self->serialize();
	print OUT $data;
	close (OUT) or croak "Error closing file: ${file}: $!";
	return $self;
}

=pod

=item fromfile_perl()

This is used to retreive options from a file.  The optionfile is actually a perl program that 
returns a hash.  By default uses option 'optionfile' as filename if none is passed.

If 'optionfile' is an array, reads all option files in order. 

Non-existant files are ignored.

Please note that values for this are cached.

	$options->fromfile_perl("/path/to/optionfile");

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
	my $n = 0;
    foreach my $f ( @{$files} ) {
        if ( exists $OPTFILE_CACHE{$f} ) {
            $self->deepmerge( $OPTFILE_CACHE{$f} );
        }
        elsif ( -e $f ) {
			if ((exists $self->{verbose}) && ($self->{verbose})) {
				print STDERR "Loading options from $f\n";
			}
            local *IN;
            my $sub = "";
            open( IN, $f ) or croak "Couldn't open option file $f: $!";
            while (<IN>) {
                $sub .= $_;
            }
            close(IN);
            my $o = $self->deserialize($sub, "Options File: $f");
			if ($o) {
				$n++;
				$OPTFILE_CACHE{$f} = $o;
			}
        }
    }
	return $n;
}

=pod

=item deserialize($data, $source)

Takes a scalar as argument and evals it, then merges option.  If second option is given uses this in error message if the eval fails.

	my $options = $options->deserialize($scalar, $source);

=cut

sub deserialize {
	my $self = shift;
	my $data = shift;
	my $source = shift || "Scalar";
	my $o = eval $data;
	if ($@) { croak "Can't process ${source}: $@" }
	else {
		$self->merge($o);
		return $self;
	}
}

=pod

=item serialize()

Output optons hash as a scalar using Data::Dumper. 

	my $scalar = $options->serialize();

=cut

sub serialize {
	my $self = shift;
	my $d = Data::Dumper->new([{ %{$self} }]);
	return $d->Purity(1)->Terse(1)->Deepcopy(1)->Dump;
}

sub DESTROY {
}

=back

=head1 BUGS

=over 4

=item Deepmerge does not handle nested references.

For example, $options->deepmerge($options) is a mess.

=item fromfile_perl provides tainted data. 

Since it comes from an external file, the data is considered tainted.

=back 4

=head1 SEE ALSO

L<Config::General>

=head1 COPYRIGHT

Copyright (c) 2007 Edward Allen III. All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the Artistic License, distributed
with Perl.


=cut

1;
