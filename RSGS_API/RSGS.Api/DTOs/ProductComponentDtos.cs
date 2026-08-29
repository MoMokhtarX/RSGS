using System.ComponentModel.DataAnnotations;
using RSGS.Api.Enums;

namespace RSGS.Api.DTOs;

public class CreateProductComponentDto
{
    [Required]
    [MinLength(2)]
    [MaxLength(50)]
    public string Code { get; set; } = string.Empty;

    [Required]
    [MinLength(2)]
    [MaxLength(250)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [EnumDataType(typeof(QuotationItemCategory))]
    public QuotationItemCategory Category { get; set; }

    [MaxLength(150)]
    public string? Brand { get; set; }

    [MaxLength(150)]
    public string? Model { get; set; }

    [MaxLength(1000)]
    public string? Specification { get; set; }

    [Required]
    [MinLength(1)]
    [MaxLength(50)]
    public string Unit { get; set; } = "pcs";

    [MaxLength(100)]
    public string? CountryOfOrigin { get; set; }

    [Range(0, 1000000000)]
    public decimal CostPrice { get; set; }

    [Range(0, 1000000000)]
    public decimal SellingPrice { get; set; }
}

public class UpdateProductComponentDto
{
    [Required]
    [MinLength(2)]
    [MaxLength(250)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [EnumDataType(typeof(QuotationItemCategory))]
    public QuotationItemCategory Category { get; set; }

    [MaxLength(150)]
    public string? Brand { get; set; }

    [MaxLength(150)]
    public string? Model { get; set; }

    [MaxLength(1000)]
    public string? Specification { get; set; }

    [Required]
    [MinLength(1)]
    [MaxLength(50)]
    public string Unit { get; set; } = "pcs";

    [MaxLength(100)]
    public string? CountryOfOrigin { get; set; }

    [Range(0, 1000000000)]
    public decimal CostPrice { get; set; }

    [Range(0, 1000000000)]
    public decimal SellingPrice { get; set; }

    public bool IsActive { get; set; } = true;
}

public class ProductComponentResponseDto
{
    public int Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    [EnumDataType(typeof(QuotationItemCategory))]
    public QuotationItemCategory Category { get; set; }
    public string? Brand { get; set; }
    public string? Model { get; set; }
    public string? Specification { get; set; }
    public string Unit { get; set; } = "pcs";
    public string? CountryOfOrigin { get; set; }
    public decimal CostPrice { get; set; }
    public decimal SellingPrice { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
