@Library('conservify') _

properties([
    disableConcurrentBuilds(),
    pipelineTriggers([githubPush()]),
    buildDiscarder(logRotator(numToKeepStr: '5'))
])

timestamps {
    node ("jenkins-aws-ubuntu") {
        try {
            def scmInfo

            stage ('prepare') {
                scmInfo = checkout scm
            }

            stage ('build') {
                sh "cargo clean"
                sh "cargo test --all"
            }

            notifySuccess()
        }
        catch (Exception e) {
            notifyFailure()
            throw e;
        }
    }
}
