using System;

namespace Demo.KQL.Functions;
public class DemoException : Exception
{
    public DemoException(string? message) : base(message)
    {
    }
}
