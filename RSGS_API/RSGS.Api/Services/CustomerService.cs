using Microsoft.EntityFrameworkCore;
using RSGS.Api.Common;
using RSGS.Api.Data;
using RSGS.Api.DTOs;
using RSGS.Api.Enums;
using RSGS.Api.Exceptions;
using RSGS.Api.Interfaces;
using RSGS.Api.Models;
using RSGS.Api.Repositories.Interfaces;
using RSGS.Api.Utilities;

namespace RSGS.Api.Services;

public class CustomerService : ICustomerService
{
    private readonly ICustomerRepository _repository;
    private readonly IActivityLogService _activityLogService;
    private readonly ICurrentUserService _currentUser;
    private readonly IAuditService _auditService;
    private readonly AppDbContext _context;

    public CustomerService(
        ICustomerRepository repository,
        IActivityLogService activityLogService,
        ICurrentUserService currentUser,
        AppDbContext context,
        IAuditService auditService)
    {
        _repository = repository;
        _activityLogService = activityLogService;
        _currentUser = currentUser;
        _context = context;
        _auditService = auditService;
    }

    public async Task<List<CustomerResponseDto>> GetAllAsync()
    {
        var engineerId = GetEngineerScope();

        if (engineerId.HasValue)
        {
            var result = await _repository.SearchAsync(
                new CustomerQueryParameters
                {
                    PageNumber = 1,
                    PageSize = int.MaxValue
                },
                engineerId.Value);

            return (result.Items ?? new List<Customer>())
                .Select(MapToResponseDto)
                .ToList();
        }

        var customers = await _repository.GetAllAsync();

        return (customers ?? new List<Customer>())
            .Select(MapToResponseDto)
            .ToList();
    }

    public async Task<CustomerResponseDto?> GetByIdAsync(int id)
    {
        var engineerId = GetEngineerScope();

        var customer = engineerId.HasValue
            ? await _repository.GetWithProjectsAsync(id, engineerId.Value)
            : await _repository.GetByIdAsync(id);

        if (customer == null)
            return null;

        return MapToResponseDto(customer);
    }

    public async Task<CustomerResponseDto> CreateAsync(CustomerDto dto)
    {
        EnsureNotEngineerForManagement();
        await ValidateAssignedUserAsync(dto.AssignedUserId);

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        var customer = new Customer
        {
            Name = dto.Name,
            Phone = dto.Phone,
            Phone2 = dto.Phone2,
            Email = dto.Email,
            Notes = dto.Notes,
            Governorate = dto.Governorate,
            City = dto.City,
            Channel = dto.Channel,

            InquiryDate = ToUtc(dto.InquiryDate),
            FollowUpStatus = dto.FollowUpStatus,
            AssignedUserId = dto.AssignedUserId,

            FirstCallNotes = dto.FirstCallNotes,
            FirstActionDate = ToUtc(dto.FirstActionDate),

            SecondCallNotes = dto.SecondCallNotes,
            SecondActionDate = ToUtc(dto.SecondActionDate),

            ThirdCallNotes = dto.ThirdCallNotes,
            ThirdActionDate = ToUtc(dto.ThirdActionDate),

            FourthCallNotes = dto.FourthCallNotes,
            FourthActionDate = ToUtc(dto.FourthActionDate),

            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await _repository.AddAsync(customer);

        await _auditService.CreateAsync(
            _currentUser.UserId,
            "Customer",
            customer.Id,
            null,
            customer,
            new[] { "Name", "Phone", "Phone2", "Email", "Notes", "Governorate", "City", "Channel", "InquiryDate", "FollowUpStatus", "AssignedUserId" });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return MapToResponseDto(customer);
    }

    public async Task<CustomerResponseDto?> UpdateAsync(
        int id,
        CustomerDto dto)
    {
        EnsureNotEngineerForManagement();
        await ValidateAssignedUserAsync(dto.AssignedUserId);

        var customer = await _repository.GetByIdAsync(id);

        if (customer == null)
            return null;

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        // Capture the immutable pre-update state BEFORE mutating the tracked entity.
        // Taking this snapshot after assignment would make the audit compare the new
        // object to itself and silently lose the actual change history.
        var previous = new
        {
            customer.Name,
            customer.Phone,
            customer.Phone2,
            customer.Email,
            customer.Notes,
            customer.Governorate,
            customer.City,
            customer.Channel,
            customer.InquiryDate,
            customer.FollowUpStatus,
            customer.AssignedUserId,
            customer.FirstCallNotes,
            customer.FirstActionDate,
            customer.SecondCallNotes,
            customer.SecondActionDate,
            customer.ThirdCallNotes,
            customer.ThirdActionDate,
            customer.FourthCallNotes,
            customer.FourthActionDate
        };

        customer.Name = dto.Name;
        customer.Phone = dto.Phone;
        customer.Phone2 = dto.Phone2;
        customer.Email = dto.Email;
        customer.Notes = dto.Notes;
        customer.Governorate = dto.Governorate;
        customer.City = dto.City;
        customer.Channel = dto.Channel;

        customer.InquiryDate = ToUtc(dto.InquiryDate);
        customer.FollowUpStatus = dto.FollowUpStatus;
        customer.AssignedUserId = dto.AssignedUserId;

        customer.FirstCallNotes = dto.FirstCallNotes;
        customer.FirstActionDate = ToUtc(dto.FirstActionDate);

        customer.SecondCallNotes = dto.SecondCallNotes;
        customer.SecondActionDate = ToUtc(dto.SecondActionDate);

        customer.ThirdCallNotes = dto.ThirdCallNotes;
        customer.ThirdActionDate = ToUtc(dto.ThirdActionDate);

        customer.FourthCallNotes = dto.FourthCallNotes;
        customer.FourthActionDate = ToUtc(dto.FourthActionDate);

        customer.UpdatedAt = DateTime.UtcNow;

        await _repository.UpdateAsync(customer);

        await _auditService.UpdateAsync(
            _currentUser.UserId,
            "Customer",
            customer.Id,
            previous,
            customer,
            new[] { "Name", "Phone", "Phone2", "Email", "Notes", "Governorate", "City", "Channel", "InquiryDate", "FollowUpStatus", "AssignedUserId", "FirstCallNotes", "FirstActionDate", "SecondCallNotes", "SecondActionDate", "ThirdCallNotes", "ThirdActionDate", "FourthCallNotes", "FourthActionDate" });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return MapToResponseDto(customer);
    }

    public async Task<bool> DeleteAsync(int id)
    {
        EnsureNotEngineerForManagement();

        var customer = await _repository.GetByIdAsync(id);

        if (customer == null)
            return false;

        // Customer has RESTRICT relationships from Projects, Quotations and Invoices.
        // Fail with a deterministic business error instead of letting a FK violation
        // surface as a generic database exception.
        var projectCount = await _context.Projects.CountAsync(x => x.CustomerId == id);
        var quotationCount = await _context.Quotations.CountAsync(x => x.CustomerId == id);
        var invoiceCount = await _context.Invoices.CountAsync(x => x.CustomerId == id);

        if (projectCount > 0 || quotationCount > 0 || invoiceCount > 0)
        {
            throw new BusinessException(
                "Cannot delete a customer that has related projects, quotations, or invoices. Remove or reassign the related records first.");
        }

        var ownsTransaction = _context.Database.CurrentTransaction == null && _context.Database.IsRelational();
        await using var transaction = ownsTransaction
            ? await _context.Database.BeginTransactionAsync()
            : null;

        try
        {
            await _repository.DeleteAsync(customer);
        }
        catch (DbUpdateException)
        {
            throw new BusinessException(
                "Customer cannot be deleted because related records were created or retained. Remove the related projects, quotations, or invoices first.");
        }

        await _auditService.DeleteAsync(
            _currentUser.UserId,
            "Customer",
            customer.Id,
            customer,
            null,
            new[] { "Name", "Phone", "Phone2", "Email", "Notes", "Governorate", "City", "Channel" });

        if (ownsTransaction)
            await transaction!.CommitAsync();

        return true;
    }

    public async Task<PagedResult<CustomerResponseDto>> SearchAsync(
        CustomerQueryParameters parameters)
    {
        var engineerId = GetEngineerScope();

        var result = await _repository.SearchAsync(
            parameters,
            engineerId);

        var customers = result.Items ?? new List<Customer>();

        return new PagedResult<CustomerResponseDto>
        {
            Items = customers
                .Select(MapToResponseDto)
                .ToList(),

            PageNumber = result.PageNumber,
            PageSize = result.PageSize,
            TotalCount = result.TotalCount
        };
    }

    private int? GetEngineerScope()
    {
        return _currentUser.Role == UserRole.Engineer.ToString()
            ? _currentUser.UserId
            : null;
    }

    private void EnsureNotEngineerForManagement()
    {
        if (GetEngineerScope().HasValue)
        {
            throw new BusinessException(
                "Engineers do not have permission to manage customers.");
        }
    }

    private async Task ValidateAssignedUserAsync(int? assignedUserId)
    {
        if (!assignedUserId.HasValue)
            return;

        var assignedUser = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == assignedUserId.Value);

        if (assignedUser == null)
            throw new BusinessException("Assigned user not found.");

        if (!assignedUser.IsActive)
            throw new BusinessException("The assigned user is disabled.");

        if (assignedUser.Role != UserRole.Engineer)
            throw new BusinessException("Customers can only be assigned to an active Engineer.");
    }

    private static CustomerResponseDto MapToResponseDto(
        Customer customer)
    {
        return new CustomerResponseDto
        {
            Id = customer.Id,
            Name = customer.Name,
            Phone = customer.Phone,
            Phone2 = customer.Phone2,
            Email = customer.Email,
            Notes = customer.Notes,
            Governorate = customer.Governorate,
            City = customer.City,
            Channel = customer.Channel,

            InquiryDate = customer.InquiryDate,
            FollowUpStatus = customer.FollowUpStatus,
            AssignedUserId = customer.AssignedUserId,

            FirstCallNotes = customer.FirstCallNotes,
            FirstActionDate = customer.FirstActionDate,

            SecondCallNotes = customer.SecondCallNotes,
            SecondActionDate = customer.SecondActionDate,

            ThirdCallNotes = customer.ThirdCallNotes,
            ThirdActionDate = customer.ThirdActionDate,

            FourthCallNotes = customer.FourthCallNotes,
            FourthActionDate = customer.FourthActionDate,

            CreatedAt = customer.CreatedAt,
            UpdatedAt = customer.UpdatedAt,

            AssignedUser = customer.AssignedUser == null
                ? null
                : new AssignedUserDto
                {
                    Id = customer.AssignedUser.Id,
                    FullName = customer.AssignedUser.FullName
                }
        };
    }

    private static DateTime? ToUtc(DateTime? date)
    {
        if (date == null)
            return null;

        return DateTimeUtility.ToUtc(date.Value);
    }
}