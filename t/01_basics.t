#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use open ':std', ':encoding(utf8)';
use Test::Most;
use File::Temp qw(tempdir);
use Path::Class qw(dir file);

use FindBin qw($Bin);
use lib "$Bin/lib";

use XML::Chain qw(xc);

my $tmp_dir = dir(tempdir( CLEANUP => 1 ));

subtest 'xc()' => sub {
    my $body = xc('body');
    isa_ok($body, 'XML::Chain::Element', 'xc(exported) returns element');
    is($body->as_string, '<body/>', 'create an element');

    my $body_class = xc('body', {'data-a' => 'b', class => 'myClass'});
    is($body_class->as_string, '<body class="myClass" data-a="b"/>', 'create an element with hash attribute');
    my $body_class2 = xc('body', class => 'myClass', onLoad => 'alert("yay!")');
    is($body_class2->as_string, '<body class="myClass" onLoad="alert(&quot;yay!&quot;)"/>', 'create an element with sorted attributes');
    my $load_file = xc([$Bin, 'tdata', '01_basics.xml']);
    is($load_file->as_string, '<hello><world/></hello>', 'create from file (IO::Any)');

    my $h1 = $body->c('h1')->t('I am heading');
    isa_ok($h1,'XML::Chain::Selector','$h1 → selector on traversal');
    is($body->as_string, '<body><h1>I am heading</h1></body>', 'selector create an element');

    is(xc(\'<body><h1>and</h1><h1>head</h1></body>')->find('//h1')->count, 2, '=head3 xc($what_ref); -> parsing xml strings');

    cmp_ok($body->as_string, 'eq', $body->toString, 'toString alias to as_string');
};

subtest 'basic creation' => sub {
    my $div = xc('div', class => 'pretty')
                ->c('h1')->t('hello')
                ->up
                ->c('p', class => 'intro')->t('world!')
                ->root;
    is($div->as_string, '<div class="pretty"><h1>hello</h1><p class="intro">world!</p></div>', '=head1 SYNOPSIS; block1 -> chained create elements');

    my $icon_el = xc('i', class => 'icon-download icon-white');
    is($icon_el->as_string, '<i class="icon-download icon-white"/>', '=head2 xc; sample');

    my $span_el = xc('span')->t('some')->t(' ')->t('more text');
    is($span_el->as_string, '<span>some more text</span>', '=head2 t; sample');

    my $over_el = xc('overload');
    is("$over_el", '<overload/>', '=head2 as_string; sample');

    my $head2_root = xc('p')
        ->t('this ')
        ->c('b')
            ->t('is')->up
        ->t(' important!')
        ->root->as_string;
    is($head2_root, '<p>this <b>is</b> important!</p>', '=head2 root; sample');

    return;
};

subtest 'navigation' => sub {
    my $body = xc('body')
                ->c('p')->t('para1')->up
                ->c('p')
                    ->t('para2 ')
                    ->c('b')->t('important')->up
                    ->t(' para2_2 ')
                    ->c('b', class => 'less')->t('less important')->up
                    ->t(' para2_3')
                    ->up
                ->c('p')->t('the last one')
                ->root;
    is($body->single->as_string, '<body><p>para1</p><p>para2 <b>important</b> para2_2 <b class="less">less important</b> para2_3</p><p>the last one</p></body>', 'test test xml');
    isa_ok($body->children->first->single->as_xml_libxml, 'XML::LibXML::Element', 'first <p>');

    is($body->root->find('//b')->count, 2, 'two <b> tags');
    is($body->root->find('//p/b[@class="less"]')->text_content, 'less important', q{find('//p/b[@class="less"]')});
    is($body->root->find('/body/p[position() = last()]')->text_content, 'the last one', q{find('/body/p[position() = last()]')});
};

subtest 'store' => sub {
    my $tmp_file = $tmp_dir->file('t01.xml');
    xc('body')->t('save me')->set_io_any([$tmp_dir, 't01.xml'])->store;
    is(xc($tmp_file)->text_content, 'save me', '=head1 CHAINED DOCUMENT METHODS; ->store() and load via file');

    xc($tmp_file)->empty->c('div')->t('updated')->store;
    is($tmp_file->slurp.'', '<body><div>updated</div></body>', 'load & ->store() via file');
};

done_testing;
