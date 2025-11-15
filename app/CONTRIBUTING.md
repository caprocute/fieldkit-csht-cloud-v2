<!-- omit in toc -->
# Contributing to FieldKit

First off, thanks for taking the time to contribute! ❤️

All types of contributions are encouraged and valued. See the [Table of Contents](#table-of-contents) for different ways to help and details about how this project handles them. Please make sure to read the relevant section before making your contribution. It will make it a lot easier for us maintainers and smooth out the experience for all involved. The community looks forward to your contributions. 🎉

> And if you like the project, but just don't have time to contribute, that's fine. There are other easy ways to support the project and show your appreciation, which we would also be very happy about:
> - Star the project
> - Tweet about it
> - Mention the project at local meetups and tell your friends/colleagues

<!-- omit in toc -->
## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [I Have a Question](#i-have-a-question)
- [I Want To Contribute](#i-want-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Your First Code Contribution](#your-first-code-contribution)
- [Styleguides](#styleguides)
  - [Commit Messages](#commit-messages)
- [Join The Project Team](#join-the-project-team)


## Code of Conduct

This project and everyone participating in it is governed by the
[FieldKit Code of Conduct](https://gitlab.com/fieldkit/app/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report unacceptable behavior
to the community manager at lindsay@conservify.org or software related questions to kate@conservify.org.


## I Have a Question 

Before you ask a question or you think you found a bug, it is best to search for existing [Issues](https://gitlab.com/fieldkit/app/issues) that might help you. Please also look through the [Support](https://www.fieldkit.org/support/) Section and [Blogs](https://www.fieldkit.org/blog/). In case you have found a suitable issue and still need clarification, you can write your question in this issue. It is also advisable to search the internet for answers first. (We will also take suggestions and contributions for blogs/support articles!)

If you then still feel the need to ask a question and need clarification, we recommend the following:

- Open an [Issue](https://gitlab.com/fieldkit/app/issues/new).
- Provide as much context as you can about what you're running into.
- Provide project and platform versions (nodejs, npm, etc), depending on what seems relevant.

We will then take care of the issue as soon as possible.

## I Want To Contribute

> ### Legal Notice 
> When contributing to this project, you must agree that you have authored 100% of the content, or that you have the necessary rights to the content and that the content you contribute may be provided under the project license.

### Reporting Bugs
<!-- omit in toc -->
#### Before Submitting a Bug Report

A good bug report shouldn't leave others needing to chase you up for more information. Therefore, we ask you to investigate carefully, collect information and describe the issue in detail in your report. Please complete the following steps in advance to help us fix any potential bug as fast as possible.

- Make sure that you are using the latest version.
- Determine if your bug is really a bug and not an error on your side e.g. using incompatible environment components/versions (especially the [firmware](https://gitlab.com/fieldkit/firmware)). If you are looking for support, you might want to check [this section](#i-have-a-question)).
- To see if other users have experienced (and potentially already solved) the same issue you are having, check if there is not already a bug report existing for your bug or error in the [issues tracker](https://gitlab.com/fieldkit/issues).

<!-- omit in toc -->
#### How Do I Submit a Good Bug Report?

> You must never report security related issues, vulnerabilities or bugs including sensitive information to the issue tracker, or elsewhere in public. Instead sensitive bugs must be sent by email to <kate@conservify.org>.

We use GitLab issues to track bugs and errors. If you run into an issue with the project:

- Open an [Issue](https://gitlab.com/fieldkit/app/issues/new). (Since we can't be sure at this point whether it is a bug or not, we ask you not to talk about a bug yet and not to label the issue.)
- Explain the behavior you would expect and the actual behavior.
- Please provide as much context as possible and describe the *reproduction steps* that someone else can follow to recreate the issue on their own. This usually includes your code. For good bug reports you should isolate the problem and create a reduced test case.
- Provide the information you collected in the previous section.

Once it's filed:

- The project team will label the issue accordingly.
- A team member will try to reproduce the issue with your provided steps. If there are no reproduction steps or no obvious way to reproduce the issue, the team will ask you for those steps and mark the issue as `needs-repro`. Bugs with the `needs-repro` tag will not be addressed until they are reproduced.
- If the team is able to reproduce the issue, it will be given a priority rating and the issue will be left to be [implemented by someone](#your-first-code-contribution).

The bug template is at [issue_template.md](issue_template.md), you can ignore Test Cases and a video is optional but appreciated!


### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for FieldKit, **including completely new features and minor improvements to existing functionality**. Following these guidelines will help maintainers and the community to understand your suggestion and find related suggestions.

<!-- omit in toc -->
#### Before Submitting an Enhancement

- Make sure that you are using the latest version.
- Perform a [search](https://gitlab.com/fieldkit/app/issues) to see if the enhancement has already been suggested. If it has, add a comment to the existing issue instead of opening a new one.
- Find out whether your idea fits with the scope and aims of the project. It's up to you to make a strong case to convince the project's developers of the merits of this feature. Keep in mind that we want features that will be useful to the majority of our users and not just a small subset. If you're just targeting a minority of users, consider writing an add-on/plugin library.

<!-- omit in toc -->
#### How Do I Submit a Good Enhancement Suggestion?

Enhancement suggestions are tracked as [GitLab issues](https://gitlab.com/fieldkit/app/issues).

- Use a **clear and descriptive title** for the issue to identify the suggestion.
- Provide a **step-by-step description of the suggested enhancement** in as many details as possible.
- **Describe the current behavior** and **explain which behavior you expected to see instead** and why. At this point you can also tell which alternatives do not work for you.
- You may want to **include screenshots and animated GIFs** which help you demonstrate the steps or point out the part which the suggestion is related to. You can use [this tool](https://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](https://github.com/GNOME/byzanz) on Linux. 
- **Explain why this enhancement would be useful** to most FieldKit users. You may also want to point out the other projects that solved it better and which could serve as inspiration.

### Your First Code Contribution
First, set up your machine according to the [README.md](README.md). If you run into any issues, be sure to document them to improve the README for others.


Next, check [here](https://gitlab.com/fieldkit/app/-/issues/?sort=closed_at_desc&state=opened&label_name%5B%5D=good%20first%20issue&first_page_size=20) if there are any issues labeled as `good first issues`. If not, check all recent [issues](https://gitlab.com/fieldkit/app/-/issues) for issues that stand out to you.

## Styleguides
### Commit Messages
Don't over complicate it but also make it informative. Start with an imperative verb and describe what you did. Useful verbs are `Fix`, `Refactor`, `Add`, `Revert`, `Style`, etc.

Examples:

- `Upgrade rustfk`
- `Merge branch '224-debug-build-crash-on-native-phone' into 'develop'`
- `Fix naming of KnownStations and clean up code`
- `Add snackbar features - textoverflow, icon, and dismiss old snackbar`
- `Refactor notifications outside of app_state.dart`


## Join The Project Team
We are currently hiring for a Operations and Fulfillment Lead and Quality Assurance Lead (may change at time of reading). Apply [here](https://www.fieldkit.org/careers/).


## Attribution
This guide is based on the [**contributing-gen**](https://github.com/bttger/contributing-gen).


<!-- omit in toc -->
## Let's get STARTED!!
Thanks for reading this! We're excited to have you contribute!