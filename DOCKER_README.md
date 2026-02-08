# UI Sample Spark

An educational ASP.NET Core application demonstrating multiple UI technologies and modern development practices.

## 🚀 Quick Start

```bash
docker pull markhazleton/uisamplespark:latest
docker run -d -p 8080:8080 markhazleton/uisamplespark:latest
```

Visit `http://localhost:8080` to see the application.

## 📋 What's Inside

This containerized application showcases:

- **Multiple UI Frameworks**: MVC, Razor Pages, Blazor, React, Vue, htmx
- **ASP.NET Core 10**: Latest .NET features and patterns
- **In-Memory Database**: EF Core with sample employee data
- **API Documentation**: Swagger/OpenAPI integration
- **Health Checks**: `/health` endpoint for monitoring

## 🏗️ Container Details

- **Base Image**: Alpine Linux (security-optimized)
- **Runtime**: .NET 10 ASP.NET runtime
- **Port**: 8080 (non-root user) 
- **Size**: ~406 MB
- **Architecture**: linux/amd64

## 🔒 Security Features

- ✅ Runs as non-root user (`appuser`)
- ✅ Alpine Linux with security updates
- ✅ Regular vulnerability scanning (Trivy)
- ✅ Weekly automated rebuilds
- ⚠️ **Educational project** - Not production-ready (no authentication)

## 🌐 Available Tags

- `latest` - Latest stable build from main branch
- `main-{sha}` - Specific commit builds
- `{build-number}` - Numbered builds

## 📚 Documentation

- **GitHub**: [https://github.com/markhazleton/UISampleSpark](https://github.com/markhazleton/UISampleSpark)
- **API Docs**: Available at `/swagger` in running container
- **License**: MIT

## 🛠️ Configuration

### Environment Variables

- `ASPNETCORE_URLS` - Listening URLs (default: `http://+:8080`)
- `APPLICATIONINSIGHTS_CONNECTION_STRING` - Azure Monitor (optional)

### Volume Mounts

No persistent volumes required - uses in-memory database for demonstration.

## 🤝 Contributing

This is an educational project. Contributions welcome! See the [GitHub repository](https://github.com/markhazleton/UISampleSpark) for details.

## 📄 License

MIT License - See [LICENSE](https://github.com/markhazleton/UISampleSpark/blob/main/LICENSE)

---

**Note**: This is an educational project designed to demonstrate ASP.NET Core features and UI patterns. It intentionally omits authentication and other production requirements to focus on core concepts.

Built with ❤️ by [Mark Hazleton](https://markhazleton.com)
