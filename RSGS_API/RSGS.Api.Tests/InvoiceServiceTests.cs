using Microsoft.EntityFrameworkCore;
using RSGS.Api.Common;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.DTOs.ActivityLogs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Services;
using Xunit;

namespace RSGS.Api.Tests;

public sealed class InvoiceServiceTests
{
    [Fact]
    public async Task InvoicePaymentWorkflow_CalculatesTotalsAllocatesInstallmentsAndMarksPaid()
    {
        await using var db = Db();
        var user = new User { Username = "admin", FullName = "Admin", Email = "a@test", Role = UserRole.Admin, IsActive = true };
        var customer = new Customer { Name = "Customer", Phone = "123" };
        db.AddRange(user, customer); await db.SaveChangesAsync();
        var service = new InvoiceService(db, new UserContext(user.Id), new Activity());
        var invoice = await service.CreateAsync(new CreateInvoiceDto
        {
            CustomerId = customer.Id, Tax = 5,
            Items = [new InvoiceItemDto { Description = "Installation", Quantity = 2, UnitPrice = 10 }]
        });
        Assert.Equal(20, invoice.Subtotal);
        Assert.Equal(25, invoice.Total);
        await service.AddInstallmentAsync(new InstallmentDto { InvoiceId = invoice.Id, Amount = 15, DueDate = DateTime.UtcNow.AddDays(1) });
        await service.AddInstallmentAsync(new InstallmentDto { InvoiceId = invoice.Id, Amount = 10, DueDate = DateTime.UtcNow.AddDays(2) });
        var payment = await service.AddPaymentAsync(new CreatePaymentDto { InvoiceId = invoice.Id, Amount = 25 });

        Assert.Equal(25, payment.Amount);
        var current = await service.GetByIdAsync(invoice.Id);
        Assert.Equal(InvoiceStatus.Paid, current!.Status);
        Assert.All(current.Installments, x => Assert.Equal(InvoiceStatus.Paid, x.Status));
    }

    [Fact]
    public async Task InvoicePaymentWorkflow_RejectsMissingCustomerOverpaymentsAndExcessInstallments()
    {
        await using var db = Db();
        var service = new InvoiceService(db, new UserContext(1), new Activity());
        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateInvoiceDto { CustomerId = 999, Items = [new InvoiceItemDto { Description = "x", Quantity = 1, UnitPrice = 1 }] }));

        var user = new User { Username = "admin", FullName = "Admin", Email = "a@test", Role = UserRole.Admin, IsActive = true };
        var customer = new Customer { Name = "Customer", Phone = "123" };
        db.AddRange(user, customer); await db.SaveChangesAsync();
        var invoice = await service.CreateAsync(new CreateInvoiceDto { CustomerId = customer.Id, Items = [new InvoiceItemDto { Description = "x", Quantity = 1, UnitPrice = 10 }] });
        await Assert.ThrowsAsync<BusinessException>(() => service.AddPaymentAsync(new CreatePaymentDto { InvoiceId = invoice.Id, Amount = 11 }));
        await Assert.ThrowsAsync<BusinessException>(() => service.AddInstallmentAsync(new InstallmentDto { InvoiceId = invoice.Id, Amount = 11, DueDate = DateTime.UtcNow }));
    }

    [Fact]
    public async Task InvoiceCreation_RejectsInvalidFinancialStatesAndDates()
    {
        await using var db = Db();
        var user = new User { Username = "admin", FullName = "Admin", Email = "state@test", Role = UserRole.Admin, IsActive = true };
        var customer = new Customer { Name = "Customer", Phone = "123" };
        db.AddRange(user, customer);
        await db.SaveChangesAsync();
        var service = new InvoiceService(db, new UserContext(user.Id), new Activity());
        var issueDate = DateTime.UtcNow;

        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateInvoiceDto
        {
            CustomerId = customer.Id, Status = InvoiceStatus.Paid,
            Items = [new InvoiceItemDto { Description = "x", Quantity = 1, UnitPrice = 10 }]
        }));

        await Assert.ThrowsAsync<BusinessException>(() => service.CreateAsync(new CreateInvoiceDto
        {
            CustomerId = customer.Id, IssueDate = issueDate, DueDate = issueDate.AddMinutes(-1),
            Items = [new InvoiceItemDto { Description = "x", Quantity = 1, UnitPrice = 10 }]
        }));
    }

    [Fact]
    public async Task InvoicePayment_RejectsPaymentBeforeIssueDate()
    {
        await using var db = Db();
        var user = new User { Username = "admin", FullName = "Admin", Email = "date@test", Role = UserRole.Admin, IsActive = true };
        var customer = new Customer { Name = "Customer", Phone = "123" };
        db.AddRange(user, customer);
        await db.SaveChangesAsync();
        var service = new InvoiceService(db, new UserContext(user.Id), new Activity());
        var issueDate = DateTime.UtcNow;
        var invoice = await service.CreateAsync(new CreateInvoiceDto
        {
            CustomerId = customer.Id, IssueDate = issueDate,
            Items = [new InvoiceItemDto { Description = "x", Quantity = 1, UnitPrice = 10 }]
        });

        await Assert.ThrowsAsync<BusinessException>(() => service.AddPaymentAsync(new CreatePaymentDto
        { InvoiceId = invoice.Id, Amount = 5, PaymentDate = issueDate.AddSeconds(-1) }));
    }

    [Fact]
    public async Task InvoiceInstallment_RejectsDueDateBeforeIssueDate()
    {
        await using var db = Db();
        var user = new User { Username = "admin", FullName = "Admin", Email = "installment@test", Role = UserRole.Admin, IsActive = true };
        var customer = new Customer { Name = "Customer", Phone = "123" };
        db.AddRange(user, customer);
        await db.SaveChangesAsync();
        var service = new InvoiceService(db, new UserContext(user.Id), new Activity());
        var issueDate = DateTime.UtcNow;
        var invoice = await service.CreateAsync(new CreateInvoiceDto
        {
            CustomerId = customer.Id, IssueDate = issueDate,
            Items = [new InvoiceItemDto { Description = "x", Quantity = 1, UnitPrice = 10 }]
        });

        await Assert.ThrowsAsync<BusinessException>(() => service.AddInstallmentAsync(new InstallmentDto
        { InvoiceId = invoice.Id, Amount = 5, DueDate = issueDate.AddSeconds(-1) }));
    }

    [Fact]
    public async Task InvoiceRead_ReportsOverdueStatusFromDueDate()
    {
        await using var db = Db();
        var user = new User { Username = "admin", FullName = "Admin", Email = "overdue@test", Role = UserRole.Admin, IsActive = true };
        var customer = new Customer { Name = "Customer", Phone = "123" };
        db.AddRange(user, customer);
        await db.SaveChangesAsync();
        var service = new InvoiceService(db, new UserContext(user.Id), new Activity());
        var invoice = await service.CreateAsync(new CreateInvoiceDto
        {
            CustomerId = customer.Id, IssueDate = DateTime.UtcNow.AddDays(-2), DueDate = DateTime.UtcNow.AddDays(-1),
            Status = InvoiceStatus.Issued,
            Items = [new InvoiceItemDto { Description = "x", Quantity = 1, UnitPrice = 10 }]
        });

        var current = await service.GetByIdAsync(invoice.Id);

        Assert.Equal(InvoiceStatus.Overdue, current!.Status);
    }

    private static AppDbContext Db() => new(new DbContextOptionsBuilder<AppDbContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private sealed class UserContext(int id) : ICurrentUserService { public int UserId => id; public string Username => "admin"; public string Role => "Admin"; public bool IsAuthenticated => true; }
    private sealed class Activity : IActivityLogService
    {
        public Task<ActivityLog> CreateAsync(int userId, string action, string entity, int entityId, string description) => Task.FromResult(new ActivityLog());
        public Task<List<ActivityLog>> GetRecentAsync(int count = 50) => Task.FromResult(new List<ActivityLog>());
        public Task<PagedResult<ActivityLogDto>> SearchAsync(ActivityLogQueryParameters parameters) => Task.FromResult(new PagedResult<ActivityLogDto>());
    }
}
