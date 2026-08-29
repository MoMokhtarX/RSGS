using Microsoft.EntityFrameworkCore;
using RSGS.Api.Enums;
using RSGS.Api.Models;

namespace RSGS.Api.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();
    public DbSet<Customer> Customers => Set<Customer>();
    public DbSet<Project> Projects => Set<Project>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<CalendarEvent> CalendarEvents => Set<CalendarEvent>();
    public DbSet<ActivityLog> ActivityLogs => Set<ActivityLog>();
    public DbSet<Quotation> Quotations => Set<Quotation>();
    public DbSet<QuotationItem> QuotationItems => Set<QuotationItem>();
    public DbSet<ProductComponent> ProductComponents => Set<ProductComponent>();
    public DbSet<CustomerFollowUp> CustomerFollowUps => Set<CustomerFollowUp>();
    public DbSet<CustomerInteraction> CustomerInteractions => Set<CustomerInteraction>();
    public DbSet<QuotationVersion> QuotationVersions => Set<QuotationVersion>();
    public DbSet<Supplier> Suppliers => Set<Supplier>();
    public DbSet<Invoice> Invoices => Set<Invoice>();
    public DbSet<InvoiceItem> InvoiceItems => Set<InvoiceItem>();
    public DbSet<Payment> Payments => Set<Payment>();
    public DbSet<Installment> Installments => Set<Installment>();
    public DbSet<PurchaseOrder> PurchaseOrders => Set<PurchaseOrder>();
    public DbSet<PurchaseOrderItem> PurchaseOrderItems => Set<PurchaseOrderItem>();
    public DbSet<InventoryStock> InventoryStocks => Set<InventoryStock>();
    public DbSet<StockMovement> StockMovements => Set<StockMovement>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // =========================
        // User
        // =========================

        modelBuilder.Entity<User>()
            .Property(x => x.Role)
            .HasConversion<string>()
            .HasMaxLength(50);

        modelBuilder.Entity<User>()
            .HasIndex(u => u.Username)
            .IsUnique();

        modelBuilder.Entity<User>()
            .HasIndex(u => u.Email)
            .IsUnique();

        // =========================
        // Customer → Project
        // =========================

        modelBuilder.Entity<Project>()
            .HasOne(p => p.Customer)
            .WithMany(c => c.Projects)
            .HasForeignKey(p => p.CustomerId)
            .OnDelete(DeleteBehavior.Restrict);

        // =========================
        // Engineer → Project
        // =========================

        modelBuilder.Entity<Project>()
            .HasOne(p => p.Engineer)
            .WithMany(u => u.Projects)
            .HasForeignKey(p => p.EngineerId)
            .OnDelete(DeleteBehavior.SetNull);

        modelBuilder.Entity<Project>()
            .Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(50);

        modelBuilder.Entity<Project>()
            .HasIndex(p => p.ProjectNumber)
            .IsUnique();

        modelBuilder.Entity<Project>()
            .Property(p => p.TotalValue)
            .HasPrecision(18, 2);

        modelBuilder.Entity<Project>()
            .Property(p => p.TotalKw)
            .HasPrecision(18, 2);

        // =========================
        // Customer → Assigned User
        // =========================

        modelBuilder.Entity<Customer>()
            .HasOne(c => c.AssignedUser)
            .WithMany(u => u.Customers)
            .HasForeignKey(c => c.AssignedUserId)
            .OnDelete(DeleteBehavior.SetNull);

        // =========================
        // Activity Log → User
        // =========================

        modelBuilder.Entity<ActivityLog>()
            .HasOne(a => a.User)
            .WithMany(u => u.ActivityLogs)
            .HasForeignKey(a => a.UserId)
            .OnDelete(DeleteBehavior.Restrict);

        // =========================
        // Customer Follow-ups / Interactions
        // =========================

        modelBuilder.Entity<CustomerFollowUp>()
            .HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<CustomerFollowUp>()
            .HasOne(x => x.User).WithMany()
            .HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<CustomerInteraction>()
            .HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<CustomerInteraction>()
            .HasOne(x => x.User).WithMany()
            .HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Restrict);

        // =========================
        // Quotation
        // =========================

        modelBuilder.Entity<Quotation>()
            .Property(q => q.Type)
            .HasConversion<string>()
            .HasMaxLength(50);

        modelBuilder.Entity<Quotation>()
            .Property(q => q.Status)
            .HasConversion<string>()
            .HasMaxLength(50);

        modelBuilder.Entity<Quotation>()
            .HasIndex(q => q.QuotationNumber)
            .IsUnique();

        modelBuilder.Entity<Quotation>()
            .HasOne(q => q.Customer)
            .WithMany(c => c.Quotations)
            .HasForeignKey(q => q.CustomerId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Quotation>()
            .HasOne(q => q.Project)
            .WithMany(p => p.Quotations)
            .HasForeignKey(q => q.ProjectId)
            .OnDelete(DeleteBehavior.SetNull);

        modelBuilder.Entity<Quotation>()
            .HasMany(q => q.Items)
            .WithOne(i => i.Quotation)
            .HasForeignKey(i => i.QuotationId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<Quotation>()
            .HasMany(q => q.Versions)
            .WithOne(v => v.Quotation)
            .HasForeignKey(v => v.QuotationId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<QuotationVersion>()
            .HasOne(v => v.CreatedByUser).WithMany()
            .HasForeignKey(v => v.CreatedByUserId).OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<QuotationVersion>()
            .HasIndex(v => new { v.QuotationId, v.VersionNumber })
            .IsUnique();

        modelBuilder.Entity<Quotation>()
            .Property(q => q.SystemCapacity)
            .HasPrecision(18, 2);

        // =========================
        // Product / Component Catalog
        // =========================

        modelBuilder.Entity<ProductComponent>()
            .Property(x => x.Category)
            .HasConversion<string>()
            .HasMaxLength(50);

        modelBuilder.Entity<ProductComponent>()
            .HasIndex(x => x.Code)
            .IsUnique();

        modelBuilder.Entity<ProductComponent>()
            .Property(x => x.CostPrice)
            .HasPrecision(18, 2);

        modelBuilder.Entity<ProductComponent>()
            .Property(x => x.SellingPrice)
            .HasPrecision(18, 2);

        // =========================
        // Quotation Items
        // =========================

        modelBuilder.Entity<QuotationItem>()
            .Property(x => x.Category)
            .HasConversion<string>()
            .HasMaxLength(50);

        modelBuilder.Entity<QuotationItem>()
            .Property(i => i.Quantity)
            .HasPrecision(18, 3);

        modelBuilder.Entity<QuotationItem>()
            .HasOne(i => i.ProductComponent)
            .WithMany(p => p.QuotationItems)
            .HasForeignKey(i => i.ProductComponentId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<QuotationItem>()
            .Property(i => i.UnitCost)
            .HasPrecision(18, 2);

        modelBuilder.Entity<QuotationItem>()
            .Property(i => i.UnitPrice)
            .HasPrecision(18, 2);

        modelBuilder.Entity<QuotationItem>()
            .Property(i => i.TotalCost)
            .HasPrecision(18, 2);

        modelBuilder.Entity<QuotationItem>()
            .Property(i => i.TotalPrice)
            .HasPrecision(18, 2);

        modelBuilder.Entity<QuotationItem>()
            .Property(i => i.SortOrder)
            .HasDefaultValue(0);

        // =========================
        // Priority 4 - Suppliers
        // =========================
        modelBuilder.Entity<Supplier>()
            .HasIndex(x => x.Code)
            .IsUnique();

        // =========================
        // Priority 4 - Invoices
        // =========================
        modelBuilder.Entity<Invoice>()
            .HasIndex(x => x.InvoiceNumber)
            .IsUnique();
        modelBuilder.Entity<Invoice>()
            .Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(50);
        modelBuilder.Entity<Invoice>()
            .HasOne(x => x.Customer).WithMany()
            .HasForeignKey(x => x.CustomerId)
            .OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<Invoice>()
            .HasOne(x => x.Project).WithMany()
            .HasForeignKey(x => x.ProjectId)
            .OnDelete(DeleteBehavior.SetNull);
        modelBuilder.Entity<Invoice>()
            .HasOne(x => x.Quotation).WithMany()
            .HasForeignKey(x => x.QuotationId)
            .OnDelete(DeleteBehavior.SetNull);
        modelBuilder.Entity<Invoice>()
            .HasOne(x => x.CreatedByUser).WithMany()
            .HasForeignKey(x => x.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<Invoice>()
            .Property(x => x.Subtotal).HasPrecision(18, 2);
        modelBuilder.Entity<Invoice>()
            .Property(x => x.Tax).HasPrecision(18, 2);
        modelBuilder.Entity<Invoice>()
            .Property(x => x.Total).HasPrecision(18, 2);
        modelBuilder.Entity<Invoice>()
            .Property(x => x.PaidAmount).HasPrecision(18, 2);
        modelBuilder.Entity<Invoice>()
            .HasMany(x => x.Items).WithOne(x => x.Invoice)
            .HasForeignKey(x => x.InvoiceId)
            .OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<Invoice>()
            .HasMany(x => x.Payments).WithOne(x => x.Invoice)
            .HasForeignKey(x => x.InvoiceId)
            .OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<Invoice>()
            .HasMany(x => x.Installments).WithOne(x => x.Invoice)
            .HasForeignKey(x => x.InvoiceId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<InvoiceItem>()
            .Property(x => x.Quantity).HasPrecision(18, 3);
        modelBuilder.Entity<InvoiceItem>()
            .Property(x => x.UnitPrice).HasPrecision(18, 2);
        modelBuilder.Entity<InvoiceItem>()
            .Property(x => x.Total).HasPrecision(18, 2);
        modelBuilder.Entity<InvoiceItem>()
            .HasOne(x => x.ProductComponent).WithMany(x => x.InvoiceItems)
            .HasForeignKey(x => x.ProductComponentId)
            .OnDelete(DeleteBehavior.SetNull);

        modelBuilder.Entity<Payment>()
            .Property(x => x.Method)
            .HasConversion<string>()
            .HasMaxLength(50);
        modelBuilder.Entity<Payment>()
            .Property(x => x.Amount).HasPrecision(18, 2);
        modelBuilder.Entity<Payment>()
            .HasOne(x => x.ReceivedByUser).WithMany()
            .HasForeignKey(x => x.ReceivedByUserId)
            .OnDelete(DeleteBehavior.Restrict);

        modelBuilder.Entity<Installment>()
            .Property(x => x.Amount).HasPrecision(18, 2);
        modelBuilder.Entity<Installment>()
            .Property(x => x.PaidAmount).HasPrecision(18, 2);
        modelBuilder.Entity<Installment>()
            .Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(50);

        // =========================
        // Priority 4 - Purchase Orders
        // =========================
        modelBuilder.Entity<PurchaseOrder>()
            .HasIndex(x => x.OrderNumber)
            .IsUnique();
        modelBuilder.Entity<PurchaseOrder>()
            .Property(x => x.Status)
            .HasConversion<string>()
            .HasMaxLength(50);
        modelBuilder.Entity<PurchaseOrder>()
            .Property(x => x.Subtotal).HasPrecision(18, 2);
        modelBuilder.Entity<PurchaseOrder>()
            .Property(x => x.Tax).HasPrecision(18, 2);
        modelBuilder.Entity<PurchaseOrder>()
            .Property(x => x.Total).HasPrecision(18, 2);
        modelBuilder.Entity<PurchaseOrder>()
            .HasOne(x => x.Supplier).WithMany(x => x.PurchaseOrders)
            .HasForeignKey(x => x.SupplierId)
            .OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<PurchaseOrder>()
            .HasOne(x => x.CreatedByUser).WithMany()
            .HasForeignKey(x => x.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<PurchaseOrder>()
            .HasMany(x => x.Items).WithOne(x => x.PurchaseOrder)
            .HasForeignKey(x => x.PurchaseOrderId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<PurchaseOrderItem>()
            .Property(x => x.Quantity).HasPrecision(18, 3);
        modelBuilder.Entity<PurchaseOrderItem>()
            .Property(x => x.ReceivedQuantity).HasPrecision(18, 3);
        modelBuilder.Entity<PurchaseOrderItem>()
            .Property(x => x.UnitCost).HasPrecision(18, 2);
        modelBuilder.Entity<PurchaseOrderItem>()
            .Property(x => x.Total).HasPrecision(18, 2);
        modelBuilder.Entity<PurchaseOrderItem>()
            .HasOne(x => x.ProductComponent).WithMany(x => x.PurchaseOrderItems)
            .HasForeignKey(x => x.ProductComponentId)
            .OnDelete(DeleteBehavior.Restrict);

        // =========================
        // Priority 4 - Inventory
        // =========================
        modelBuilder.Entity<InventoryStock>()
            .HasIndex(x => x.ProductComponentId)
            .IsUnique();
        modelBuilder.Entity<InventoryStock>()
            .Property(x => x.QuantityOnHand).HasPrecision(18, 3);
        modelBuilder.Entity<InventoryStock>()
            .Property(x => x.ReorderLevel).HasPrecision(18, 3);
        modelBuilder.Entity<InventoryStock>()
            .HasOne(x => x.ProductComponent).WithOne(x => x.InventoryStock)
            .HasForeignKey<InventoryStock>(x => x.ProductComponentId)
            .OnDelete(DeleteBehavior.Cascade);

        modelBuilder.Entity<StockMovement>()
            .Property(x => x.Type)
            .HasConversion<string>()
            .HasMaxLength(50);
        modelBuilder.Entity<StockMovement>()
            .Property(x => x.Quantity).HasPrecision(18, 3);
        modelBuilder.Entity<StockMovement>()
            .HasOne(x => x.ProductComponent).WithMany(x => x.StockMovements)
            .HasForeignKey(x => x.ProductComponentId)
            .OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<StockMovement>()
            .HasOne(x => x.CreatedByUser).WithMany()
            .HasForeignKey(x => x.CreatedByUserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}