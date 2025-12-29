# 3D Figure Scanner

iOS app that uses LiDAR technology to scan faces and bodies for 3D printing.

![iOS](https://img.shields.io/badge/iOS-16.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

- **Face Scan**: Detailed facial capture with guided scanning
- **Body Scan**: Full 360° body scanning
- **Bust Scan**: Head and shoulders capture
- **Export Formats**: STL, OBJ, GLTF, USDZ, PLY
- **3D Preview**: View and rotate your scans in AR

## Requirements

- iPhone 12 Pro or later (with LiDAR sensor)
- iPad Pro 2020 or later (with LiDAR sensor)
- iOS 16.0+

## Installation

### Prerequisites

- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### Build

```bash
# Clone the repository
git clone https://github.com/nguyenductho89/3dFigures.git
cd 3dFigures

# Generate Xcode project
xcodegen generate

# Open in Xcode
open FigureScanner3D.xcodeproj
```

## Project Structure

```
3dFigures/
├── FigureScanner3D/
│   ├── App/                 # App entry point
│   ├── Features/
│   │   ├── Scanning/        # Face, Body, Bust scanning
│   │   ├── Gallery/         # Saved scans management
│   │   ├── Preview/         # 3D model preview
│   │   ├── Export/          # Export functionality
│   │   └── Settings/        # App settings
│   ├── Core/
│   │   ├── Services/        # Business logic
│   │   ├── Models/          # Data models
│   │   └── Utilities/       # Helper functions
│   └── Resources/           # Assets, Info.plist
├── FigureScanner3DTests/    # Unit tests
├── FigureScanner3DUITests/  # UI tests
├── docs/                    # Documentation
└── project.yml              # XcodeGen config
```

## Documentation

See the [docs](./docs) folder for detailed documentation:

- [PRD](./docs/PRD.md) - Product Requirements
- [Technical Architecture](./docs/TECHNICAL_ARCHITECTURE.md)
- [User Stories](./docs/USER_STORIES.md)
- [Wireframes](./docs/WIREFRAMES.md)

## CI/CD

This project uses GitHub Actions with a self-hosted runner:

- **CI**: Builds and tests on every push/PR
- **Release**: Creates releases on version tags

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.
