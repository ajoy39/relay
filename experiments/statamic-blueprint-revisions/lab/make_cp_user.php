<?php
// make_cp_user.php — create the gate's throwaway control-panel super user.
// Run through tinker by build_lab.sh, with LAB_SPEC_JS naming the lab's copy
// of spec/gate.spec.js. The login lives only there (lines 21-22, labelled a
// throwaway): it is read from the file and never printed, logged or written
// anywhere else.
use Statamic\Facades\User;

$spec = getenv('LAB_SPEC_JS');
$js = ($spec && is_readable($spec)) ? file_get_contents($spec) : '';
$get = function ($field) use ($js) {
    return preg_match('/fill\(\'[^\']*"' . $field . '"[^\']*\',\s*\'([^\']*)\'\)/', $js, $m) ? $m[1] : null;
};
$email = $get('email');
$password = $get('password');
if (!$email || !$password) { fwrite(STDERR, "CP USER: BROKEN — login not found in LAB_SPEC_JS\n"); exit(3); }

// Never print an exception message here: Laravel's QueryException embeds the
// SQL with its bound values, which once printed the lab email and password
// hash (2026-10-31). Only the exception's class is shown.
try {
    $user = User::findByEmail($email) ?? User::make()->email($email);
    $user->set('name', 'Lab Admin')->password($password)->makeSuper()->save();
} catch (\Throwable $e) {
    fwrite(STDERR, "CP USER: BROKEN — " . get_class($e) . " (message suppressed: it may contain the login)\n");
    exit(3);
}
echo "CP USER: super user present (", User::all()->count(), " user(s) total)\n";
