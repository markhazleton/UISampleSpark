using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace UISampleSpark.Core.Tests.Extensions;

/// <summary>
/// Defines test class StringExtensionsTests.
/// </summary>
[TestClass()]
public class StringExtensionsTests
{
    /// <summary>
    /// Defines the test method GetDecimalFromStringTest.
    /// </summary>
    [TestMethod()]
    public void GetDecimalFromStringTest()
    {
        string myTest = "1.99";
        decimal myDefault = 2.99M;

        decimal myValue = myTest.GetDecimalFromString(myDefault);
        Assert.AreEqual((decimal)1.99, myValue);
    }

    /// <summary>
    /// Defines the test method GetDecimalFromStringTestInvalidString.
    /// </summary>
    [TestMethod()]
    public void GetDecimalFromStringTestInvalidString()
    {
        string myTest = "INVALID";
        decimal myDefault = 2.99M;
        decimal myValue = myTest.GetDecimalFromString(myDefault);
        Assert.AreEqual(myDefault, myValue);
    }

    /// <summary>
    /// Defines the test method GetDecimalFromStringTestNullString.
    /// </summary>
    [TestMethod()]
    public void GetDecimalFromStringTestNullString()
    {
        string? myTest = null;
        decimal myDefault = 2.99M;
        decimal myValue = myTest.GetDecimalFromString(myDefault);
        Assert.AreEqual(myDefault, myValue);
    }

    /// <summary>
    /// Defines the test method GetIntFromStringTest.
    /// </summary>
    [TestMethod()]
    public void GetIntFromStringTest()
    {
        string myTest = "1";
        int? myDefault = 0;

        int? myValue = myTest.GetIntFromString(myDefault);
        Assert.AreEqual(1, myValue);
    }

    /// <summary>
    /// Defines the test method GetIntFromStringTestInvalidString.
    /// </summary>
    [TestMethod()]
    public void GetIntFromStringTestInvalidString()
    {
        string myTest = "INVALID";
        int? myDefault = 0;
        int? myValue = myTest.GetIntFromString(myDefault);
        Assert.AreEqual(myDefault, myValue);
    }

    /// <summary>
    /// Defines the test method GetIntFromStringTestNullDefault.
    /// </summary>
    [TestMethod()]
    public void GetIntFromStringTestNullDefault()
    {
        string? myTest = null;
        int? myDefault = null;
        int? myValue = myTest.GetIntFromString(myDefault);
        Assert.AreEqual(myDefault, myValue);
    }

    /// <summary>
    /// Defines the test method GetIntFromStringTestNullString.
    /// </summary>
    [TestMethod()]
    public void GetIntFromStringTestNullString()
    {
        string? myTest = null;
        int? myDefault = 0;
        int? myValue = myTest.GetIntFromString(myDefault);
        Assert.AreEqual(myDefault, myValue);
    }

    /// <summary>
    /// Defines the test method GetNullIntFromStringTest.
    /// </summary>
    [TestMethod()]
    public void GetNullIntFromStringTest()
    {
        string myTest = "1";
        int myValue = myTest.GetIntFromString(0);
        Assert.AreEqual(1, myValue);
    }

    /// <summary>
    /// Defines the test method GetNullIntFromStringTestInvalidString.
    /// </summary>
    [TestMethod()]
    public void GetNullIntFromStringTestInvalidString()
    {
        string myTest = "INVALID";
        int myValue = myTest.GetIntFromString(0);
        Assert.AreEqual(0, myValue);
    }

    /// <summary>
    /// Defines the test method GetNullIntFromStringTestNullString.
    /// </summary>
    [TestMethod()]
    public void GetNullIntFromStringTestNullString()
    {
        string? myTest = null;
        int myValue = myTest.GetIntFromString(0);
        Assert.AreEqual(0, myValue);
    }

    /// <summary>
    /// Defines the test method IndexOfNthTest.
    /// </summary>
    [TestMethod()]
    public void IndexOfNthTest()
    {
        string myTest = "0123456789";
        Assert.AreEqual(3, myTest.IndexOfNth("3", 1));
    }

    /// <summary>
    /// Defines the test method IndexOfNthTestMultipleFind.
    /// </summary>
    [TestMethod()]
    public void IndexOfNthTestMultipleFind()
    {
        string myTest = "333333";
        Assert.AreEqual(2, myTest.IndexOfNth("3", 3));
    }

    /// <summary>
    /// Defines the test method IndexOfNthTestSourceNull.
    /// </summary>
    [TestMethod()]
    public void IndexOfNthTestSourceNotFound()
    {
        string myTest = "123456";
        int result = myTest.IndexOfNth("7", 3);
        Assert.AreEqual(result, -1);
    }

    /// <summary>
    /// Defines the test method IndexOfNthTestSourceNull.
    /// </summary>
    [TestMethod()]
    public void IndexOfNthTestSourceNull()
    {
        int result = StringExtensions.IndexOfNth(null, "3", 3);
        Assert.AreEqual(result, 0);
    }

    /// <summary>
    /// Defines the test method IndexOfNthTestValueNegativeNth. Throws exception
    /// </summary>
    [TestMethod()]
    public void IndexOfNthTestValueNegativeNth()
    {
        string myTest = "333333";
        bool exceptionThrown = false;
        try
        {
            myTest.IndexOfNth("3", -1);
        }
        catch (ArgumentException)
        {
            exceptionThrown = true;
        }
        Assert.IsTrue(exceptionThrown, "Expected ArgumentException was not thrown");
    }

    /// <summary>
    /// Defines the test method IndexOfNthTestValueNull.
    /// </summary>
    [TestMethod()]
    public void IndexOfNthTestValueNull()
    {
        string? search = default;
        string myTest = "333333";
        Assert.AreEqual(0, myTest.IndexOfNth(search, 3));
    }
    /// <summary>
    /// Defines the test method LeftTest.
    /// </summary>
    [TestMethod()]
    public void LeftTest_ShortString()
    {
        string myTest = "01";
        Assert.AreEqual("01", myTest.Left(5));
    }
    /// <summary>
    /// Defines the test method LeftTest.
    /// </summary>
    [TestMethod()]
    public void LeftTest()
    {
        string myTest = "0123456789";
        Assert.AreEqual("01", myTest.Left(2));
    }

    /// <summary>
    /// Defines the test method LeftTestNullShortString.
    /// </summary>
    [TestMethod()]
    public void LeftTestNullShortString()
    {
        Assert.AreEqual(string.Empty, StringExtensions.Left(null, 8));
    }

    /// <summary>
    /// Defines the test method LeftTestNullString.
    /// </summary>
    [TestMethod()]
    public void LeftTestNullString()
    {
        Assert.AreEqual(string.Empty, StringExtensions.Left(null, 2));
    }

    /// <summary>
    /// Defines the test method LeftTest.
    /// </summary>
    [TestMethod()]
    public void LeftTest_NegativeLength()
    {
        string myTest = "01";
        bool exceptionThrown = false;
        try
        {
            _ = myTest.Left(-1);
        }
        catch (ArgumentException)
        {
            exceptionThrown = true;
        }
        Assert.IsTrue(exceptionThrown, "Expected ArgumentException was not thrown");
    }

    /// <summary>
    /// Defines the test method RightTest.
    /// </summary>
    [TestMethod()]
    public void RightTest()
    {
        string myTest = "0123456789";
        Assert.AreEqual("89", myTest.Right(2));
    }

    /// <summary>
    /// Defines the test method RightTestNullString.
    /// </summary>
    [TestMethod()]
    public void RightTestNullString()
    {
        Assert.AreEqual(string.Empty, StringExtensions.Right(null, 2));
    }

    /// <summary>
    /// Defines the test method RightTestToShort.
    /// </summary>
    [TestMethod()]
    public void RightTestToShort()
    {
        string myTest = "01";
        Assert.AreEqual("01", myTest.Right(8));
    }

    /// <summary>
    /// Defines the test method TrimIfNotNullTest.
    /// </summary>
    [TestMethod()]
    public void TrimIfNotNullTest()
    {
        string myTest = "   MyTest   ";
        Assert.AreEqual("MyTest", myTest.TrimIfNotNull());
    }

    /// <summary>
    /// Defines the test method TrimIfNotNullTestWithNull.
    /// </summary>
    [TestMethod()]
    public void TrimIfNotNullTestWithNull()
    {
        string? myTest = null;
        string myResult = myTest.TrimIfNotNull();
        Assert.AreEqual(string.Empty, myResult);
    }
}
