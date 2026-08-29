using System.ComponentModel.DataAnnotations;
using RSGS.Api.DTOs;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class DtoValidationTests
{
    [Theory]
    [MemberData(nameof(InvalidRequests))]
    public void InvalidRequests_FailDataAnnotationValidation(object request)
    {
        var results = new List<ValidationResult>();
        var valid = Validator.TryValidateObject(request, new ValidationContext(request), results, validateAllProperties: true);

        Assert.False(valid);
        Assert.NotEmpty(results);
    }

    public static IEnumerable<object[]> InvalidRequests()
    {
        yield return [new CustomerDto { Name = "", Phone = "not a phone" }];
        yield return [new CreateUserDto { Username = "", Password = "12345678901", FullName = "", Email = "invalid" }];
        yield return [new CreateProductComponentDto { Code = "x", Name = "x", Unit = "", CostPrice = -1, SellingPrice = -1 }];
        yield return [new InvoiceItemDto { Description = "", Quantity = 0, UnitPrice = -1 }];
        yield return [new CreateProjectDto { ProjectNumber = "", Name = "", CustomerId = 0, Latitude = 91, Longitude = 181 }];
        yield return [new ChangePasswordDto { CurrentPassword = "", NewPassword = "12345678901", ConfirmPassword = "" }];
    }

    [Fact]
    public void ValidCustomerRequest_PassesDataAnnotationValidation()
    {
        var customer = new CustomerDto { Name = "Production Customer", Phone = "+201234567890", Email = "customer@example.test" };
        var results = new List<ValidationResult>();

        Assert.True(Validator.TryValidateObject(customer, new ValidationContext(customer), results, true));
    }
}
