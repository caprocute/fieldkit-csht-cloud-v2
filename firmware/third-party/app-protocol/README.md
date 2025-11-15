# FK-App-Protocol

## Description

The `fk-app-protocol` is the Google Protocol Buffers specification for the communications between a FieldKit device and the FieldKit mobile application. This protocol defines the structure and types of messages exchanged, ensuring robust and efficient communication.

## Requirements
- `git`
- `npm`
  
Depending on your enviroment:
- `Python` and `pytest`
- `Javascript` and `mocha`
- `Go`
- `Java` and `JUnit`
- `Dart`
- `xcode` and `Swift`
- `C++` and `GoogleTest`
- `C` and `CMock`

## Build and Installation

```
git clone https://gitlab.com/fieldkit/libraries/app-protocol
sudo apt install protobuf-compiler
```

## Run the Code / Example

Use this format to output a protocol in the language that your project supports.
```
protoc --[language]_out=[output directory] [source directory]/*.proto
```

For example, for python:
```
protoc --python_out=./ *.proto
```

## Dependencies

The project relies on `protobufjs` for handling Protocol Buffers in JavaScript. Ensure you have the following dependency installed:

- `protobufjs` version `^6.8.0`

To install the dependencies, run:

```
npm install
```

## Contributing

We welcome contributions to the `fk-app-protocol` project. If you'd like to contribute, please fork the repository and use a feature branch. Pull requests are warmly welcome. Contact us if you need any information.

## License

Copyright 2023 FieldKit

This software is provided under a specific license that includes certain conditions and disclaimers. Please see the full [LICENSE](./LICENSE) for more details.

## Contact Information

- **Author**: Jacob Lewallen
- **Email**: [jacob@conservify.org](mailto:jacob@conservify.org)