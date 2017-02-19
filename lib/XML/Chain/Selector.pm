package XML::Chain::Selector;

use warnings;
use strict;
use utf8;
use 5.010;

our $VERSION = '0.02';

use Moose;
use MooseX::Aliases;
use Carp qw(croak);
use XML::Tidy;

has 'current_elements' => (is => 'rw', isa => 'ArrayRef', default => sub {[]});
has '_xc' => (is => 'rw', isa => 'XML::Chain', required => 1);

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
            my $child_el = $self->{_xc}->_create_element($el_name, $ns_uri, @attrs);
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
            return $self->{_xc}->_xc_el($parent_el);
        })
    ]);
}

alias root => 'document_element';
sub document_element {
    my ($self) = @_;
    return $self->_new_related([$self->{_xc}->document_element]);
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
                map { $self->{_xc}->_xc_el($_) }
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
            return map { $self->{_xc}->_xc_el($_) } $el->{lxml}->childNodes;
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

sub auto_indent {
    my ($self, $set_to) = @_;
    croak 'need true/false/options for auto indentation ' if @_ < 2;

    $self->_cur_el_iterrate(sub {$_[0]->{auto_indent} = $set_to});

    return $self;
}

### methods

alias toString => 'as_string';
sub as_string {
    my ($self) = @_;
    return join('', $self->_cur_el_iterrate(sub {
        my ($el) = @_;

        my $auto_indent       = $el->{auto_indent};
        my $auto_indent_chars = ((ref($auto_indent) eq 'HASH') ? $auto_indent->{chars} : undef);
        $auto_indent_chars = "\t"
            unless defined($auto_indent_chars);

        return (
            $auto_indent
            ? XML::Tidy->new(xml => $el->{lxml})->tidy($auto_indent_chars)->toString
            : $el->{lxml}->toString
        )
    }));
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

sub single {
    my ($self) = @_;
    croak 'more current elements then one'
        if @{$self->current_elements} > 1;
    croak 'no current element' unless @{$self->current_elements} == 1;
    return @{$self->current_elements}[0];
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
        _xc              => $self->{_xc},
    );
}

1;


__END__

=encoding utf8

=head1 NAME

XML::Chain::Selector - selector for traversing the XML::Chain

=head1 SYNOPSIS

    my $user = xc('user', xmlns => 'testns')
                ->auto_indent(1)
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

Will print:

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

=head2 auto_indent

    my $simple = xc('div')
                    ->auto_indent(1)
                    ->c('div')->t('in')
                    ->root;
    say $simple->as_string;

Will print:

    <div>
        <div>in</div>
    </div>

Turn on/off tidy/auto-indentation of document elements. Default indentation
characters are tabs.

Argument can be either true/false scalar or a hashref with indentation
options. Currently C< {chars=>' 'x4} > will set indentation characters to
be four spaces.

NOTE Currently works only on element on which C<as_string()> is called
     using L<HTML::Tidy>.
     In the future it is planned to be possible to set idendentation
     on/off also for nested elements. For example not to indend embedded
     html elements.

WARNING L<HTML::Tidy> has a circular reference and leaks memory when used.
        Better don't use auto_indent() at in this version in persistant
        environments.

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

=head2 single

    my $lxml_el = $xc->find('//b')->first->as_xml_libxml;

Checks is there is exactly one element in current elements and return it
as L<XML::Chain::Element> object.

=head1 AUTHOR

Jozef Kutej

=head1 COPYRIGHT & LICENSE

Copyright 2017 Jozef Kutej, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
