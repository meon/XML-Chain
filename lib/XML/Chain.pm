package XML::Chain;

use warnings;
use strict;
use utf8;
use 5.010;

our $VERSION = '0.07';

use XML::LibXML;
use XML::Chain::Selector;
use XML::Chain::Element;
use Carp qw(croak confess);
use Scalar::Util qw(blessed);
use IO::Any;
use Moose;
use Moose::Exporter;
use Try::Tiny;
Moose::Exporter->setup_import_methods(as_is => ['xc'],);

has 'dom' => (is => 'rw', isa => 'XML::LibXML::Document', lazy_build => 1);
has '_xml_libxml' => (
    is      => 'rw',
    isa     => 'XML::LibXML',
    lazy    => 1,
    default => sub {XML::LibXML->new}
);

sub _build_dom {
    my ($self) = @_;
    return $self->_xml_libxml->createDocument("1.0", "UTF-8");
}

sub xc {
    my ($el_name_object, @attrs) = @_;

    my $self = __PACKAGE__->new();

    my $initial_el = $self->_create_element($el_name_object, undef, @attrs);
    confess 'document creation must be from single element'
        unless @$initial_el == 1;

    $self->dom->setDocumentElement($initial_el->[0]->{lxml});
    return $self->document_element;
}

sub _create_element {
    my ($self, $el_name_object, $ns, @attrs) = @_;

    if (@attrs == 1) {
        my $hash_attrs = $attrs[0];
        croak 'with two argument second argument must be hashref'
            unless ref($hash_attrs) eq 'HASH';
        @attrs = map { $_ => $hash_attrs->{$_} } sort keys %$hash_attrs;
    }

    $ns //= {@attrs}->{xmlns} // '';

    my @create_elements;
    if (@attrs) {
        # lxml create
    }
    if (ref($el_name_object)) {
        if (blessed($el_name_object)) {
            if ($el_name_object->isa('XML::Chain::Selector')) {
                @create_elements = @{$el_name_object->current_elements};
            }
            elsif ($el_name_object->isa('XML::LibXML::Document')) {
                @create_elements = $self->_xc_el_data($el_name_object->documentElement);
            }
            elsif ($el_name_object->isa('XML::LibXML::Node')) {
                @create_elements = $self->_xc_el_data($el_name_object);
            }
        }

        unless (@create_elements) {
            $self->{io_any} = $el_name_object;
            my $dom = XML::LibXML->load_xml(
                string => IO::Any->slurp($el_name_object),
            );
            @create_elements = $self->_xc_el_data($dom->documentElement);
        }
    }
    else {
        # lxml create
    }

    unless (@create_elements) {
        my $new_element = $self->dom->createElementNS($ns, $el_name_object);
        while (@attrs) {
            my $attr_name  = shift(@attrs);
            my $attr_value = shift(@attrs);
            next unless defined($attr_name);
            next unless defined($attr_value);
            if ($attr_name eq '-') {
                $new_element->appendText($attr_value);
            }
            else {
                try {
                    $new_element->setAttribute($attr_name => $attr_value);
                }
                catch {
                    confess 'failed to set attribute "'.$attr_name.'" on "'.$el_name_object.'" - '.$_;
                };
            }
        }
        @create_elements = $self->_xc_el_data($new_element);
    }

    return \@create_elements;
}

sub _xc_el_data {
    my ($self, $el) = @_;
    croak 'need element as argument' unless defined($el);

    my $eid = $el->unique_key;
    return $self->{_xc_el_data}->{$eid} //= {
        eid  => $eid,
        lxml => $el,
        ns   => ($el->namespaceURI // ''),
    };
}

sub _lxml_document_element {
    return $_[0]->dom->documentElement;
}

sub _xc {return $_[0];}

sub document_element {
    my ($self) = @_;
    return XML::Chain::Element->new(
        _xc_el_data => $self->_xc_el_data($self->_lxml_document_element),
        _xc         => $self,
    );
}

sub store {
    my ($self) = @_;
    my $io_any = $self->{io_any};
    my $io_any_opts = $self->{io_any_opts} // {};
    croak 'io_any was not set' unless $io_any;
    IO::Any->spew($io_any, $self->document_element->as_string, {atomic => 1, %$io_any_opts});
    return $self->document_element;
}

sub set_io_any {
    my ($self, $to_set, $opts) = @_;
    $self->{io_any} = $to_set;
    $self->{io_any_opts} = $opts // {};
    return $self->document_element;
}

1;

__END__

=encoding utf8

=head1 NAME

XML::Chain - chained way of manipulating and inspecting XML documents

=head1 SYNOPSIS

    use XML::Chain qw(xc);

    # basics
    my $div = xc('div', class => 'pretty')
                ->c('h1')->t('hello')
                ->up
                ->c('p', class => 'intro')->t('world')
                ->root
                ->a( xc('p')->t('of chained XML.') );
    say $div->as_string;
    # <div class="pretty"><h1>hello</h1><p class="intro">world</p><p>of chained XML.</p></div>

    my $sitemap =
        xc('urlset', xmlns => 'http://www.sitemaps.org/schemas/sitemap/0.9')
        ->t("\n")
        ->c('url')
            ->a('loc',        '-' => 'https://metacpan.org/pod/XML::Chain::Selector')
            ->a('lastmod',    '-' => DateTime->from_epoch(epoch => 1507451828)->strftime('%Y-%m-%d'))
            ->a('changefreq', '-' => 'monthly')
            ->a('priority',   '-' => '0.6')
        ->up->t("\n")
        ->c('url')
            ->a('loc',        '-' => 'https://metacpan.org/pod/XML::Chain::Element')
            ->a('lastmod',    '-' => DateTime->from_epoch(epoch => 1507279028)->strftime('%Y-%m-%d'))
            ->a('changefreq', '-' => 'monthly')
            ->a('priority',   '-' => '0.5')
        ->up->t("\n");
    say $sitemap->as_string;
    # <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    # <url><loc>https://metacpan.org/pod/XML::Chain::Selector</loc><lastmod>2017-10-08</lastmod><changefreq>monthly</changefreq><priority>0.6</priority></url>
    # <url><loc>https://metacpan.org/pod/XML::Chain::Element</loc><lastmod>2017-10-06</lastmod><changefreq>monthly</changefreq><priority>0.5</priority></url>
    # </urlset>

=head1 DESCRIPTION

This module provides fast and easy way to create and manipulate XML elements
via set of chained method calls.

=head1 EXPORTS

=head2 xc

Exported factory method creating new L<XML::Chain::Element> object with
a document element as provided in parameters. For example:

    my $icon = xc('i', class => 'icon-download icon-white');
    # <i class="icon-download icon-white"/>

See also L<XML::Chain::Selector/c, append_and_current>, from which
L<XML::Chain::Element> inherits all methods, for the element parameter
description and L<XML::Chain::Selector/CHAINED METHODS> for methods of
returned object.

=head3 xc($el_name, @attrs) scalar with 1+ arguments

Element with C<$el_name> will be create as document element and C< @attrs >
will be added to it in the same order.

In case of hash reference passed as argument, key + values will be set
as attributes, in alphabetical sorted key name order.

Attribute name "-" is a special case and the value will used for text
content inside the element.

=head3 xc($xml_libxml_ref)

In case of XML::LibXML, it will be set as document element.

=head3 xc($what_ref)

Any other reference will be passed to L<IO::Any/slurp($what)> which will
be then parsed by L<XML::LibXML/load_xml> and result set as document element.

    say xc([$tmp_dir, 't01.xml'])->as_string
    say xc(\'<body><h1>and</h1><h1>head</h1></body>')
            ->find('//h1')->count

=head3 xc($scalar)

Element with C<$scalar> will be create as document element.

    say xc('body');

=head1 CHAINED METHODS, METHODS and ELEMENT METHODS

See L<XML::Chain::Selector> and L<XML::Chain::Element>.

=head1 CHAINED DOCUMENT METHODS

    xc('body')->t('save me')->set_io_any([$tmp_dir, 't01.xml'])->store;
    # $tmp_dir/t01.xml file now consists of:
        <body>save me</body>
    xc([$tmp_dir, 't01.xml'])->empty->c('div')->t('updated')->store;
    # $tmp_dir/t01.xml file now consists of:
        <body><div>updated</div></body>

=head2 set_io_any

Store C< $what , $options > of L<IO::Any> for future use with C< -E<gt>store() >

=head2 store

Calls C<< IO::Any->spew($io_any, $self->as_string, {atomic => 1}) >> to
save XML back it it's original file of the the target set via
C<set_io_any>.

=head1 TODO

    - partial/special tidy (on elements inside xml)
    - per ->data() storage
    - ->each(sub {...}) / ->map(sub {}) / ->grep(sub {})
    - setting and handling namespaces and elements with ns prefixes
    - ~ton of selectors and manipulators to be added

=head1 CONTRIBUTORS & CREDITS

Initially inspired by Strophe.Builder, then also by jQuery.

The following people have contributed to the XML::Chain by committing their
code, sending patches, reporting bugs, asking questions, suggesting useful
advice, nitpicking, chatting on IRC or commenting on my blog (in no particular
order):

    Slaven Rezic
    Vienna.pm (for listening to my talk and providing valuable feedback)
    Mohammad S Anwar
    you?

Also thanks to my current day-job-employer L<http://geizhals.at/>.

=head1 BUGS

Please report any bugs or feature requests via L<https://github.com/meon/XML-Chain/issues>.

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2017 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
