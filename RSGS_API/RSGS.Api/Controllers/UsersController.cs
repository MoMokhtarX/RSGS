using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RSGS.Api.DTOs;
using RSGS.Api.Interfaces;
using RSGS.Api.Filters;

namespace RSGS.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController : BaseApiController
{
    private readonly IUserService _userService;
    private readonly ICurrentUserService _currentUser;

    public UsersController(
        IUserService userService,
        ICurrentUserService currentUser)
    {
        _userService = userService;
        _currentUser = currentUser;
    }

    // =========================
    // GET ALL USERS
    // =========================

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll()
    {
        return Success(await _userService.GetAllAsync());
    }

    // =========================
    // GET USER BY ID
    // =========================

    [HttpGet("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetById(int id)
    {
        var user = await _userService.GetByIdAsync(id);

        if (user == null)
            return NotFoundResponse("User not found.");

        return Success(user);
    }

    // =========================
    // CREATE USER
    // =========================

    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(CreateUserDto dto)
    {
        var user = await _userService.CreateAsync(dto);

        return CreatedResponse(
            user,
            "User created successfully.");
    }

    // =========================
    // UPDATE USER
    // =========================

    [HttpPut("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(
        int id,
        UpdateUserDto dto)
    {
        var user = await _userService.UpdateAsync(id, dto);

        if (user == null)
            return NotFoundResponse("User not found.");

        return Success(
            user,
            "User updated successfully.");
    }

    // =========================
    // DELETE USER
    // =========================

    [HttpDelete("{id}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _userService.DeleteAsync(id);

        if (!deleted)
            return NotFoundResponse("User not found.");

        return Success(
            "",
            "User deleted successfully.");
    }

    // =========================
    // CHANGE PASSWORD
    // =========================

    [HttpPost("{id:int}/change-password")]
    [TypeFilter(typeof(ChangePasswordOwnershipFilter))]
    public async Task<IActionResult> ChangePassword(
        int id,
        ChangePasswordDto dto)
    {
        var result =
            await _userService.ChangePasswordAsync(id, dto);

        if (!result)
            return NotFound();

        return Success(
            message: "Password changed successfully.");
    }

    // =========================
    // RESET PASSWORD
    // =========================

    [HttpPost("{id}/reset-password")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ResetPassword(
        int id,
        ResetPasswordDto dto)
    {
        var result =
            await _userService.ResetPasswordAsync(
                id,
                dto.NewPassword);

        if (!result)
            return NotFoundResponse("User not found.");

        return Success(
            message: "Password reset successfully.");
    }

    // =========================
    // DISABLE USER
    // =========================

    [HttpPut("{id}/disable")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Disable(int id)
    {
        var result =
            await _userService.SetActiveAsync(
                id,
                false);

        if (!result)
            return NotFoundResponse("User not found.");

        return Success(
            message: "User disabled successfully.");
    }

    // =========================
    // ENABLE USER
    // =========================

    [HttpPut("{id}/enable")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Enable(int id)
    {
        var result =
            await _userService.SetActiveAsync(
                id,
                true);

        if (!result)
            return NotFoundResponse("User not found.");

        return Success(
            message: "User enabled successfully.");
    }
}