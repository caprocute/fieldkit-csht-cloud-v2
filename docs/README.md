# FieldKit Engineering

Starting to gather definitions and other process related information in here so that the team has an easy reference as these things are easy to forget.

## Definitions

To run this project, you will need to add the following environment variables to your .env file

`FK`

This is a common abbreviation for FieldKit, especially in the source code.

`NS, NS8, NS#`

Abbreviation for NativeScript and its major versions. NativeScript is the framework we use to build the app in that allows us to write code that mostly targets both platforms (iOS / Android)

`Repository, Repo`

Typically this is referring to a “Source Repository” or a “Git Repository” (both are the same)

`Branch`

Our version control system, Git, keeps track of changes to the source code and files by collecting like changes onto branches. Some branches stick around for a long time and some branches pop in and out of existence as needed. Typically, changes from one branch end up being “Merged” into other branches.

`Merge`

This is the process of taking two branches and merging the changes of one into the other.

`develop`

This is where the active development version of a particular deployable/artifact resides. This is where changes land first so that they can be tested. Typically this is also the version that QA is testing and is what people are mostly interested in when they're downloading from the [distribution site](https://code.conservify.org/distribution)

`main`

Main has the up to date production or release version of that specific artifact/deployable.

`feature branch`

Sometimes a feature will take longer than others or need significant changes to complete and in those situations we'll create a separate branch for those changes. In the end this branch is merged into `develop`

## Repositories

All of our source repositories are hosted on GitHub and are visible to the public.
Most of them are hosted under the [FieldKit](https://github.com/fieldkit) organization and a few are hosted under the [Conservify](https://github.com/conservify) organization.

We follow a very strict [Git branching model](https://nvie.com/posts/a-successful-git-branching-model), which is mostly important for the firmware and so it's easier just to follow the same process everywhere. If you're curious, here's the [full description](https://nvie.com/posts/a-successful-git-branching-model/) if the summary here isn't enough:

Here's [another tutorial](https://medium.com/crowdbotics/a-dead-simple-intro-to-github-for-the-non-technical-f9d56410a856) on general Git concepts that claims to be less technical.

### https://github.com/fieldkit/mobile

A bulk of the mobile application. There are a few repositories that hold supporting libraries that are also included but all application releases are made from this repositori.

### https://github.com/fieldkit/cloud

Portal and backend code. Note: This is just the portal and the backend for the portal, code for the wordpress site is in a separate repository.

### https://github.com/fieldkit/firmware

Firmware for the stations.

## Versions

Our versions can be a little intimidating and so here's a breakdown of what's happening with them. First, a majority of the complexity is there to support development and isn't necessarily useful for production releases.


Let's start with a simple version, taken directly from the portal.

`0.2.1-main.7-12d43e85`

Each version is composed from several smaller pieces:

`0.2.1`

This is major, minor and patch version for this artifact. These behave like normal version numbers we're used to and are usually all end users will need to give us for us to know which version they're on. |

`main`

Next is the repository branch that this build came from. For end-users this will usually be `main` because that's the branch we do all our public releases from. Internally, though it'll be common to see other values here. The most common, by far, will be `develop` as that's the branch that all the active work happens on. There are some situations where internally we'll see other branches here, specifically feature branches. Though this will be on the rare side as we would rather test things in `develop` when we can.

`7`

This is the pre-release version and is assigned by Jenkins. This is where the old build number migrated to and will start with 0 for each branch and increase on each build. It's only here to easily tell the difference between two subsequent versions on a `feature` branch or on `develop` as the major, minor, and patch versions only change we we perform a release. Larger numbers are more recently built.

`12d43e85`

This is the Git hash of the branch at the time of the build. In the end this is incredibly specific and unique. With just this field alone we can find the exact moment in the repository that was distributed.

Here are some example versions and a description of them:

`0.1.1-develop-34-ecf856`

Straightforward build from the develop branch, so only visible internally.

`0.1.2-main-3-56adef3`

This is a public release and came after the example version before (`0.1.1` vs `0.1.2`) It's not a significant change, though because only the patch version was incremented.

`0.2.1-zeus-3-8b557d20`

Definitely an internal build, in this case from the `feature/zeus` branch. It's newer than the previous release, though because `0.2.1` is newer than `0.1.2`

`0.2.1-develop-500-8b557d20`

A develop build of the same major/minor/patch version. What's interesting about this one is the git hashes are identical, which means these builds are identical. Will typically happen after a simple merge.

## Submitting Bugs

Our ecosystem is made up of several pieces working together and so determining where an issues lies can be an art in itself. It never hurts to collect all the information you can, especially when a bug is new/foreign.

In addition to gathering the information below, it's incredibly helpful to include a description of what you were doing and what you expected to happen. If you're able to reproduce the issue, including those steps will almost always speed the process along.

### Hardware / Firmware

For issues directly related to the behavior of the hardware or data gathering, etc... the logs that are written to the SD card are usually the first place to go. The preferred process for submitting those involves creating a ZIP archive, preferabbly using these instructions:

	1. Make a new folder in the SD drive: [station name]_yyyy_mm_dd_HHMM
	2. Copy ALL files to that new folder
	3. Zip the folder
	4. Send it!

### App

The app is always logging behind the scenes and those logs can be submitted as diagnostics from the app by navigating to the `Developer` menu. This is available from the `Application Settings` icon in the bottom right of the bottom navigation.

### Portal

We have yet to install a formal mechanism for gathering client-side logs or other diagnostics information. In general screenshots go a long way here. Try and include the browser URL in them.

## Hardware Details

I2C: RTC, INA219 Bat, INA219 Sol, Backplane MCP, Backplane LED, Backplane TCA, Core temp gauge. Module EEPROM.

## Station Interaction

### Debug Mode

Right most button.

### Emergency Rescue

Left most button.


### IRQs

SysTick
SVC
PendSV
WDT
EIC-11 Wifi
EIC-12 Battery
