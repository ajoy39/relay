<?php
use Statamic\Facades\Blueprint;
$bp = Blueprint::find('collections.pages.page');
if (!$bp) exit(9);
$c = $bp->contents();
$c['tabs']['main']['sections'][0]['fields'][1]['field']['display'] = 'Body';
$bp->setContents($c)->save();
echo "RESET\n";
