<?php
// Prints the current body display label so the gate can verify a restore took effect.
use Statamic\Facades\Blueprint;
$bp = Blueprint::find('collections.pages.page');
if (!$bp) { echo "MISSING\n"; exit(9); }
$c = $bp->contents();
echo ($c['tabs']['main']['sections'][0]['fields'][1]['field']['display'] ?? 'ABSENT'), "\n";
