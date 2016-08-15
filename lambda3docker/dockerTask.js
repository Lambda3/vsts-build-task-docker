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
        var command = tl.getInput('command', true);
        switch (command) {
            case "clean":
                bash.arg("--clean");
                bash.arg("--image");
                bash.arg(tl.getInput('imageClean', true));
                var env = tl.getInput('env', false);
                if (env) {
                    bash.arg("--env");
                    bash.arg(env);
                }
                break;
            case "build":
                bash.arg("--build");
                bash.arg("--image");
                bash.arg(tl.getInput('imageBuild', true));
                var env = tl.getInput('env', false);
                if (env) {
                    bash.arg("--env");
                    bash.arg(env);
                }
                var context = tl.getInput('context', false);
                if (context) {
                    bash.arg("--context");
                    bash.arg(context);
                }
                break;
            case "compose":
                bash.arg("--compose");
                var composeDir = tl.getPathInput('composeDir', false, false);
                tl.cd(composeDir);
                var env = tl.getInput('env', false);
                if (env) {
                    bash.arg("--env");
                    bash.arg(env);
                }
                var sshServer = tl.getInput('sshServer', false);
                if (sshServer) {
                    bash.arg("--server");
                    bash.arg(sshServer);
                }
                var sshPort = tl.getInput('sshPort', false);
                if (sshPort) {
                    bash.arg("--port");
                    bash.arg(sshPort);
                }
                var sshUser = tl.getInput('sshUser', false);
                if (sshUser) {
                    bash.arg("--user");
                    bash.arg(sshUser);
                }
                var sshKey = tl.getInput('sshKey', false);
                if (sshKey) {
                    bash.arg("--key");
                    bash.arg(sshKey);
                }
                var project = tl.getInput('project', false);
                if (project) {
                    bash.arg("--project");
                    bash.arg(project);
                }
                break;
            case "push":
                bash.arg("--push");
                bash.arg("--image");
                bash.arg(tl.getInput('imagePush', true));
                break;
        }
        bash.exec({ failOnStdErr: false, outStream: process.stdout, errStream: process.stdout }).then(function (code) {
            if (command == 'build') {
                cwd = cwd || process.cwd();
                var artifactName = "docker";
                var stagingFolder = tl.getVariable('build.stagingdirectory');
                stagingFolder = path.join(stagingFolder, artifactName);
                tl.rmRF(stagingFolder);
                tl.mkdirP(stagingFolder);
                var allFiles = tl.find(cwd);
                tl.debug("allFiles contains " + allFiles.length + " files");
                var realPattern = path.join(cwd, "docker-compose*");
                var matches = tl.match(allFiles, realPattern, { matchBase: true });
                matches.push(path.join(cwd, 'imageVersion.txt'));
                for (var file of matches) {
                    tl.cp("-Rf", file, stagingFolder);
                }
                var data = {
                    artifacttype: "container",
                    artifactname: artifactName,
                    containerfolder: artifactName,
                    localpath: stagingFolder
                };
                tl.command("artifact.upload", data, stagingFolder);
            }
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
