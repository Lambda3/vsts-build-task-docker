var path = require('path');
var tl = require('vso-task-lib');

function run() {
    try {
        var dockerTaskSh = path.join(__dirname, 'dockerTask.sh');
        var bash = tl.createToolRunner(tl.which('bash', true));
        var cwd = tl.getPathInput('cwd', false, false);
        if (cwd) {
            tl.mkdirP(cwd);
            tl.cd(cwd);
        }
        bash.arg(dockerTaskSh);
        bash.arg(tl.getInput('args', false));
        bash.exec({ failOnStdErr: false }).then(function (code) {
            tl.setResult(tl.TaskResult.Succeeded, "Docker script executed successfully.");
        }).catch(function (err) {
            tl.setResult(tl.TaskResult.Failed, "Docker script failed:" + err.message);
        });
    }
    catch (err) {
        tl.setResult(tl.TaskResult.Failed, "Docker script failed:" + err.message);
    }
}
run();