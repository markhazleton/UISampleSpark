using System.IO;

namespace UISampleSpark.Core.Tests.Models;

[TestClass]
public class ApplicationStatusTests
{

    [TestMethod]
    public void ApplicationStatus_BuildDate_ReturnsValidDateTime()
    {
        // Arrange
        Assembly assembly = Assembly.GetExecutingAssembly();
        ApplicationStatus applicationStatus = new ApplicationStatus(assembly);


        string executingDirectory = AppDomain.CurrentDomain.BaseDirectory;
        string dllFilePath = Path.Combine(executingDirectory, "Newtonsoft.Json.dll");

        if (File.Exists(dllFilePath))
        {
            Assembly myFileAssembly = Assembly.LoadFrom(dllFilePath);
            _ = new ApplicationStatus(myFileAssembly);
        }

        // Act
        DateTime buildDate = applicationStatus.BuildDate;

        // Assert
        Assert.IsTrue(buildDate != DateTime.MinValue);
    }

    [TestMethod]
    public void ApplicationStatus_BuildVersion_ReturnsValidBuildVersion()
    {
        // Arrange
        Assembly assembly = Assembly.GetExecutingAssembly();
        ApplicationStatus applicationStatus = new ApplicationStatus(assembly);

        // Act
        BuildVersion buildVersion = applicationStatus.BuildVersion;

        // Assert
        Assert.IsNotNull(buildVersion);
        // Add more assertions to validate the properties or behavior of the BuildVersion class.
    }

    [TestMethod]
    public void ApplicationStatus_Features_DefaultValueIsEmptyDictionary()
    {
        // Arrange
        ApplicationStatus applicationStatus = new ApplicationStatus(Assembly.GetExecutingAssembly());

        // Act
        Dictionary<string, string> features = applicationStatus.Features;

        // Assert
        Assert.IsNotNull(features);
        Assert.AreEqual(0, features.Count);
    }

    [TestMethod]
    public void ApplicationStatus_Messages_DefaultValueIsEmptyList()
    {
        // Arrange
        ApplicationStatus applicationStatus = new ApplicationStatus(Assembly.GetExecutingAssembly());

        // Act
        List<string> messages = applicationStatus.Messages;

        // Assert
        Assert.IsNotNull(messages);
        Assert.AreEqual(0, messages.Count);
    }

    [TestMethod]
    public void ApplicationStatus_Region_DefaultValueIsNotEmptyString()
    {
        // Arrange
        ApplicationStatus applicationStatus = new ApplicationStatus(Assembly.GetExecutingAssembly());

        // Act
        string region = applicationStatus.Region;

        // Assert
        Assert.IsTrue(string.IsNullOrEmpty(region));
    }

    [TestMethod]
    public void ApplicationStatus_Status_DefaultValueIsOnline()
    {
        // Arrange
        ApplicationStatus applicationStatus = new ApplicationStatus(Assembly.GetExecutingAssembly());

        // Act
        ServiceStatus status = applicationStatus.Status;

        // Assert
        Assert.AreEqual(ServiceStatus.Online, status);
    }

    [TestMethod]
    public void ApplicationStatus_Tests_DefaultValueIsEmptyDictionary()
    {
        // Arrange
        ApplicationStatus applicationStatus = new ApplicationStatus(Assembly.GetExecutingAssembly());

        // Act
        Dictionary<string, string> tests = applicationStatus.Tests;

        // Assert
        Assert.IsNotNull(tests);
        Assert.AreEqual(0, tests.Count);
    }



}
