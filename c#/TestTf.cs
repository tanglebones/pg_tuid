using NUnit.Framework;

namespace Tuid
{
    [TestFixture]
    public sealed class TestTf
    {
        [Test]
        public void Test()
        {
            var t = Default.Generator.Generate();
            System.Console.WriteLine(t);
            Assert.AreEqual(36,t.Length);
        }
    }
}