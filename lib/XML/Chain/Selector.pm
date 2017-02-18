package XML::Chain::Selector;

use warnings;
use strict;
use utf8;

our $VERSION = '0.02';

use Moose;
use MooseX::Aliases;
use Carp qw(croak);

has 'current_elements' => (is => 'rw', isa => 'ArrayRef', default => sub {[]});
has 'xc' => (is => 'rw', isa => 'XML::Chain', required => 1);

use overload '""' => \&as_string, fallback => 1;

### chained methods

alias c => 'append_and_current';
sub append_and_current {
    my ($self, $el_name, @attrs) = @_;

    my $attrs_ns_uri = {@attrs}->{xmlns};

    return $self->_new_related([
        $self->_cur_el_iterrate(sub {
            my ($el) = @_;
            my $ns_uri = $attrs_ns_uri // $el->{ns};
            my $child_el = {
                ns   => $ns_uri,
                lxml => $self->xc->_create_element($el_name, $ns_uri, @attrs),
            };
            $el->{lxml}->appendChild($child_el->{lxml});
            return $child_el;
        })
    ]);
}

alias t => 'append_text';
sub append_text {
    my ($self, $text) = @_;

    $self->_cur_el_iterrate(sub {
        return $_[0]->{lxml}->appendText($text);
    });

    return $self;
}

alias up => 'parent';
sub parent {
    my ($self) = @_;

    return $self->_new_related([
        $self->_cur_el_iterrate(sub {
            my ($el) = @_;
            my $parent_el = $el->{lxml}->parentNode;
            return {
                ns   => $parent_el->namespaceURI // '',
                lxml => $parent_el,
            };
        })
    ]);
}

sub root {
    my ($self) = @_;
    return $self->_new_related([$self->xc->document_element]);
}

sub find {
    my ($self, $xpath) = @_;
    croak 'need xpath as argument' unless defined($xpath);

    my $xpc = XML::LibXML::XPathContext->new();
    return $self->_new_related([
        $self->_cur_el_iterrate(sub {
            my ($el) = @_;
            my $lxml_el = $el->{lxml};
            return
                map { +{
                    ns   => $_->namespaceURI // '',
                    lxml => $_,
                } }
                $xpc->findnodes($xpath, $lxml_el )
            ;
        })
    ]);

    return $self;
}

sub children {
    my ($self) = @_;

    return $self->_new_related([
        $self->_cur_el_iterrate(sub {
            my ($el) = @_;
            return map { +{
                ns   => $_->namespaceURI,
                lxml => $_,
            } } $el->{lxml}->childNodes;
        })
    ]);
}

sub first {
    my ($self) = @_;
    return $self->_new_related(
        [     @{$self->current_elements}
            ? @{$self->current_elements}[0]
            : ()
        ]
    );
}

sub set_auto_indent {
    return $_[0]->auto_indent(1);
}

sub auto_indent {
    my ($self) = @_;

    warn 'TODO';

    if (@_) {
        my $set_to = shift(@_);

        # TODO set auto indent for current element(s)....
    }

    # TODO return current element(s) auto indent....

    return $self;
}

### methods

alias toString => 'as_string';
sub as_string {
    my ($self) = @_;
    return join('', $self->_cur_el_iterrate(sub { $_[0]->{lxml}->toString }));
}

sub text_content {
    my ($self) = @_;

    my $text = '';
    $self->_cur_el_iterrate(sub {
        my ($el) = @_;
        $text .= $el->{lxml}->textContent;
        return $el;
    });

    return $text;
}

sub as_xml_libxml {
    my ($self) = @_;

    my @elements;
    $self->_cur_el_iterrate(sub {
        my ($el) = @_;
        push(@elements, $el->{lxml});
    });

    return @elements;
}

alias size => 'count';
sub count {
    my ($self) = @_;
    my $count = 0;
    $self->_cur_el_iterrate(sub {$count++});
    return $count;
}

### helpers

sub _cur_el_iterrate {
    my ($self, $code_ref) = @_;
    croak 'need code ref a argument' unless ref($code_ref) eq 'CODE';
    return map { $code_ref->($_) } @{$self->current_elements};
}

sub _new_related {
    my ($self, $current_elements) = @_;
    croak 'need array ref a argument' unless ref($current_elements) eq 'ARRAY';
    return __PACKAGE__->new(
        current_elements => $current_elements,
        xc               => $self->xc,
    );
}

1;


__END__

=encoding utf8

=head1 NAME

XML::Chain::Selector - selector for traversing the XML::Chain

=head1 SYNOPSIS

    my $user = xc('user', xmlns => 'testns')
                ->set_auto_indent
                ->c('name')->t('Johnny Thinker')->up
                ->c('username')->t('jt')->up
                ->c('bio')
                    ->c('div', xmlns => 'http://www.w3.org/1999/xhtml')
                        ->c('h1')->t('about')->up
                        ->c('p')->t('...')->up
                    ->up
                ->c('greeting')->t('Hey')
                ->root;
    say $user->as_string;

Will produce (currently not-indented, set_auto_indent is work in progress):

    <user xmlns="testns">
        <name>Johnny Thinker</name>
        <username>jt</username>
        <bio>
            <div xmlns="http://www.w3.org/1999/xhtml">
                <h1>about</h1>
                <p>...</p>
            </div>
            <greeting>Hey</greeting>
        </bio>
    </user>

=head1 DESCRIPTION

=head1 CHAINED METHODS

=head2 c, append_and_current

Appends new element to current elements and changes context to them. New
element is defined in parameters:

    $xc->c('i', class => 'icon-download icon-white')
    # <i class="icon-download icon-white"/>

First parameter is name of the element, then followed by optional element
attributes.

=head2 t, append_text

Appends text to current elements.

    xc('span')->t('some')->t(' ')->t('more text')
    # <span>some more text</span>

First parameter is name of the element, then followed by optional element
attributes.

=head2 root

Sets document element as current element.

    say xc('p')
        ->t('this ')
        ->c('b')
            ->t('is')->up
        ->t(' important!')
        ->root->as_string;
    # <p>this <b>is</b> important!</p>

=head2 up, parent

Traverse current elements and replace them by their parents.

=head2 find

    say $xc->find('//p/b[@class="less"]')->text_content;

Look-up elements by xpath and set them as current elements.

=head2 children

Set all current elements child nodes as current elements.

=head2 first

Set first current elements as current elements.

=head2 auto_indet / set_auto_indent

TODO

Turn on tidy/auto-indentation of document elements.

=head1 METHODS

=head2 as_string, toString

Returns string representation of current XML elements. Call L<root> before
to get a string representing the whole document.

    $xc->as_string
    $xc->root->as_string

=head2 as_xml_libxml

Returns array of current elements as L<XML::LibXML> objects.

=head2 text_content

Returns text content of all current XML elements.

=head2 count / size

    say $xc->find('//b')->count;

Return the number of current elements.

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2017 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
