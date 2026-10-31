<?php
// make_fixture.php — create the run-07 fixture blueprint in the database.
// Run through tinker by build_lab.sh. The gate's fixture scripts address the
// body field as tabs.main.sections[0].fields[1] and reset its display to
// "Body", so that exact shape is load-bearing.
use Statamic\Facades\Blueprint;

$bp = Blueprint::find('collections.pages.page') ?? Blueprint::make('page')->setNamespace('collections.pages');
$bp->setContents([
    'title' => 'Page',
    'tabs' => [
        'main' => [
            'display' => 'Main',
            'sections' => [[
                'fields' => [
                    ['handle' => 'title',   'field' => ['type' => 'text', 'display' => 'Title', 'required' => true]],
                    ['handle' => 'content', 'field' => ['type' => 'markdown', 'display' => 'Body']],
                ],
            ]],
        ],
    ],
])->save();

$c = Blueprint::find('collections.pages.page')->contents();
echo 'FIXTURE body_display=', $c['tabs']['main']['sections'][0]['fields'][1]['field']['display'], "\n";
