<?php
// Makes two real blueprint edits so a working tracker records two revisions.
use Statamic\Facades\Blueprint;
$bp = Blueprint::find('collections.pages.page');
if (!$bp) { fwrite(STDERR, "FIXTURE MISSING\n"); exit(9); }
foreach (['Body v2', 'Body v3'] as $label) {
    $c = $bp->contents();
    $c['tabs']['main']['sections'][0]['fields'][1]['field']['display'] = $label;
    $bp->setContents($c)->save();
    $bp = Blueprint::find('collections.pages.page');
    usleep(1100000); // distinct timestamps
}
$c = $bp->contents();
echo "SEEDED current_body_display=", $c['tabs']['main']['sections'][0]['fields'][1]['field']['display'], "\n";
