readme:
	cpanm -l dzil-local -n Pod::Markdown
	PATH=$(PATH):dzil-local/bin PERL5LIB=dzil-local/lib/perl5 pod2markdown lib/CloudFormation/DSL.pm > README.md

dist: readme
	cpanm -n -l dzil-local Dist::Zilla
	PATH=$(PATH):dzil-local/bin PERL5LIB=dzil-local/lib/perl5 dzil authordeps --missing | cpanm -n -l dzil-local/
	PATH=$(PATH):dzil-local/bin PERL5LIB=dzil-local/lib/perl5 dzil build

test:
	PERL5LIB=local/lib/perl5 prove -I lib -v t/
