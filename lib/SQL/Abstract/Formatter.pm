package SQL::Abstract::Formatter;

require SQL::Abstract::Parts; # it loads us too, don't cross the streams

use Moo;

has indent_by => (is => 'ro', default => '  ');
has max_width => (is => 'ro', default => 78);

sub _join {
  shift;
  return SQL::Abstract::Parts::stringify(\@_);
}

sub format {
  my ($self, $join, @parts) = @_;
  $self->_fold_sql('', '', @{$self->_simplify($join, @parts)});
}

sub _simplify {
  my ($self, $join, @parts) = @_;
  return '' unless @parts;
  return $parts[0] if @parts == 1 and !ref($parts[0]);
  return $self->_simplify(@{$parts[0]}) if @parts == 1;
  return [ $join, map ref() ? $self->_simplify(@$_) : $_, @parts ];
}

sub _fold_sql {
  my ($self, $indent0, $indent, $join, @parts) = @_;
  my @res;
  my $w = $self->max_width;
  my $join_len = 0;
  (s/, \Z/,\n/ and $join_len = 1)
    or s/\A /\n/
    or $_ = "\n"
      for my $line_join = $join;
  my ($nl_pre, $nl_post) = split "\n", $line_join;
  my $line_orig = my $line = $indent0;
  my $next_indent = $indent.$self->indent_by;
  my $line_proto = $indent.$nl_post;
  PART: foreach my $idx (0..$#parts) {
    my $p = $parts[$idx];
    my $pre = ($line ne $line_orig ? $join : '');
    my $j_part = $pre.(my $j = ref($p) ? $self->_join(@$p) : $p);
    if (length($j_part) + length($line) + $join_len <= $w) {
      $line .= $j_part;
      next PART;
    }
    if (ref($p) and $p->[1] eq '(' and $p->[-1] eq ')') {
      my $already = !($line eq $indent0 or $line eq $line_orig);
      push @res, $line.($already ? $join : '').'('."\n";
      my (undef, undef, $inner) = @$p;
      my $folded = $self->_fold_sql($next_indent, $next_indent, @$inner);
      $folded =~ s/\n\Z//;
      push @res, $folded."\n";
      $line_orig = $line
         = $indent0.')'.(
           ($nl_post and $idx < $#parts) ? ' '.$nl_post : ' '
         );
      next PART;
    }
    push @res, $line.$nl_pre."\n" if $line ne $line_orig;
    if (length($line = $line_proto.$j) <= $w) {
      $line_proto = $line;
      next PART;
    }
    my $innerdent = @res ? $indent : $next_indent;
    my $folded = $self->_fold_sql($line_proto, $innerdent, @$p);
    $folded =~ s/\n\Z//;
    push @res, $folded.$nl_pre."\n";
    $line_orig = $line = $idx == $#parts ? '' : $line_proto;
  }
  return join '', @res, $line;
}

1;  
