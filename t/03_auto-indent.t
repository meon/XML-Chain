#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use open ':std', ':encoding(utf8)';
use Test::Most;

use FindBin qw($Bin);
use lib "$Bin/lib";

use XML::Chain qw(xc);

subtest 'auto indent (synopsis of XML::Chain::Selector)' => sub {
    local $TODO = 'to be done...';

    # namespaces && auto indentation
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
    eq_or_diff_text($user->as_string, user_as_string(), 'auto indented user');
};


done_testing;

sub user_as_string {
    return <<'__USER_AS_STRING__'
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
__USER_AS_STRING__
}
