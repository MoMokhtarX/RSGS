using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace RSGS.Api.Migrations
{
    /// <inheritdoc />
    public partial class Priority2ComponentsAndQuotationPricing : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "product_component_id",
                table: "QuotationItems",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "total_cost",
                table: "QuotationItems",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "total_price",
                table: "QuotationItems",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "unit_cost",
                table: "QuotationItems",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "unit_price",
                table: "QuotationItems",
                type: "numeric(18,2)",
                precision: 18,
                scale: 2,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "product_components",
                columns: table => new
                {
                    id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    code = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    name = table.Column<string>(type: "character varying(250)", maxLength: 250, nullable: false),
                    category = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    brand = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    model = table.Column<string>(type: "character varying(150)", maxLength: 150, nullable: true),
                    specification = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    unit = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    country_of_origin = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    cost_price = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    selling_price = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_product_components", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_QuotationItems_product_component_id",
                table: "QuotationItems",
                column: "product_component_id");

            migrationBuilder.CreateIndex(
                name: "IX_product_components_code",
                table: "product_components",
                column: "code",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_QuotationItems_product_components_product_component_id",
                table: "QuotationItems",
                column: "product_component_id",
                principalTable: "product_components",
                principalColumn: "id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_QuotationItems_product_components_product_component_id",
                table: "QuotationItems");

            migrationBuilder.DropTable(
                name: "product_components");

            migrationBuilder.DropIndex(
                name: "IX_QuotationItems_product_component_id",
                table: "QuotationItems");

            migrationBuilder.DropColumn(
                name: "product_component_id",
                table: "QuotationItems");

            migrationBuilder.DropColumn(
                name: "total_cost",
                table: "QuotationItems");

            migrationBuilder.DropColumn(
                name: "total_price",
                table: "QuotationItems");

            migrationBuilder.DropColumn(
                name: "unit_cost",
                table: "QuotationItems");

            migrationBuilder.DropColumn(
                name: "unit_price",
                table: "QuotationItems");
        }
    }
}
