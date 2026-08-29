using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;
using RSGS.Api.DTOs;
using RSGS.Api.Models;
using RSGS.Api.Enums;

namespace RSGS.Api.PDF;

public class QuotationPdfDocument : IDocument
{
    private readonly QuotationResponseDto _quotation;
    private readonly Customer _customer;
    private readonly Project? _project;

    public QuotationPdfDocument(
        QuotationResponseDto quotation,
        Customer customer,
        Project? project)
    {
        _quotation = quotation;
        _customer = customer;
        _project = project;
    }

    private static string GetAssetPath(string fileName)
    {
        return Path.Combine(
            AppContext.BaseDirectory,
            "PDF",
            "Assets",
            fileName);
    }

    public DocumentMetadata GetMetadata()
    {
        return new DocumentMetadata
        {
            Title = $"عرض سعر - {_quotation.QuotationNumber}",
            Author = "RSGS",
            Subject = "عرض سعر محطة طاقة شمسية",
            Keywords = "Solar Energy, Quotation, عرض سعر"
        };
    }

    public void Compose(IDocumentContainer container)
    {
        container.Page(page =>
        {
            page.Size(PageSizes.A4);
            page.MarginHorizontal(30);
            page.MarginVertical(25);

            // Arabic RTL
            page.ContentFromRightToLeft();

            page.DefaultTextStyle(
                TextStyle.Default
                    .FontFamily("Lato", "Noto Sans Arabic")
                    .FontSize(10));

            page.Header()
                .Element(ComposeHeader);

            page.Content()
                .PaddingTop(15)
                .Element(ComposeContent);

            page.Footer()
                .Element(ComposeFooter);
        });
    }

    // =========================
    // Header
    // =========================

    private void ComposeHeader(IContainer container)
    {
        container.Column(column =>
        {
            column.Item()
                .Row(row =>
                {
                    row.RelativeItem()
                        .AlignRight()
                        .AlignMiddle()
                        .Height(75)
                        .Image(GetAssetPath("logo.png"))
                        .FitHeight();

                    row.RelativeItem()
                        .AlignLeft()
                        .AlignMiddle()
                        .Column(info =>
                        {
                            info.Item()
                                .AlignLeft()
                                .Text(GetQuotationTypeName(_quotation.Type))
                                .Bold()
                                .FontSize(24)
                                .FontColor("#08777D");
                        });
                });

            column.Item()
                .PaddingTop(8)
                .Height(3)
                .Background("#159FA5");

            column.Item()
                .PaddingTop(8)
                .Row(row =>
                {
                    row.RelativeItem()
                        .Text($"رقم العرض: {_quotation.QuotationNumber}")
                        .Bold();

                    row.RelativeItem()
                        .AlignCenter()
                        .Text(
                            $"التاريخ: {_quotation.QuotationDate:yyyy/MM/dd}");

                    row.RelativeItem()
                        .AlignLeft()
                        .Text(
                            $"صالح حتى: {_quotation.ValidUntil:yyyy/MM/dd}");
                });
        });
    }

    // =========================
    // Customer Information
    // =========================

    private void ComposeCustomerSection(IContainer container)
    {
        container
            .Background("#F5FAFA")
            .Border(1)
            .BorderColor("#D6E7E8")
            .Padding(12)
            .Column(column =>
            {
                column.Item()
                    .Text("بيانات العميل")
                    .Bold()
                    .FontSize(14)
                    .FontColor("#138F96");

                column.Item()
                    .PaddingTop(8)
                    .Row(row =>
                    {
                        row.RelativeItem()
                            .Text($"اسم العميل: {_customer.Name}");

                        row.RelativeItem()
                            .Text($"الهاتف: {_customer.Phone}");
                    });

                column.Item()
                    .PaddingTop(5)
                    .Row(row =>
                    {
                        row.RelativeItem()
                            .Text(
                                $"البريد الإلكتروني: {_customer.Email ?? "-"}");

                        row.RelativeItem()
                            .Text(
                                $"المحافظة: {_customer.Governorate ?? "-"}");
                    });

                column.Item()
                    .PaddingTop(5)
                    .Row(row =>
                    {
                        row.RelativeItem()
                            .Text(
                                $"المدينة: {_customer.City ?? "-"}");

                        row.RelativeItem()
                            .Text(
                                $"المشروع: {_project?.Name ?? "-"}");
                    });

                if (_project != null &&
                    !string.IsNullOrWhiteSpace(_project.Address))
                {
                    column.Item()
                        .PaddingTop(5)
                        .Text($"عنوان المشروع: {_project.Address}");
                }
            });
    }

    // =========================
    // Content
    // =========================

    private void ComposeContent(IContainer container)
    {
        container.Column(column =>
        {
            column.Spacing(12);

            // Customer information
            column.Item()
                .Element(ComposeCustomerSection);

            // Introduction
            if (!string.IsNullOrWhiteSpace(_quotation.Introduction))
            {
                column.Item()
                    .Element(ComposeIntroduction);
            }

            // System description
            if (!string.IsNullOrWhiteSpace(_quotation.SystemDescription) ||
                _quotation.SystemCapacity > 0)
            {
                column.Item()
                    .Element(ComposeSystemDescription);
            }

            // Items
            column.Item()
                .Element(ComposeItemsTable);

            // Total
            column.Item()
                .PaddingTop(10)
                .Element(ComposeTotal);

            // Terms
            column.Item()
                .PaddingTop(15)
                .Element(ComposeTerms);

            // Stamp
            column.Item()
                .Element(ComposeStamp);
        });
    }

    // =========================
    // Introduction
    // =========================

    private void ComposeIntroduction(IContainer container)
    {
        container
            .Padding(5)
            .Text(_quotation.Introduction!)
            .FontSize(11);
    }

    // =========================
    // System Description
    // =========================

    private void ComposeSystemDescription(IContainer container)
    {
        container
            .Background("#FCFEFE")
            .Border(1)
            .BorderColor("#D6E7E8")
            .Padding(10)
            .Column(column =>
            {
                column.Item()
                    .Text("بيان النظام")
                    .Bold()
                    .FontSize(13)
                    .FontColor("#08777D");

                column.Item()
                    .PaddingTop(5)
                    .Text(
                        $"توريد محطة كاملة لتوليد الكهرباء بالطاقة الشمسية بقدرة قصوى {_quotation.SystemCapacity:N2} كيلو وات شاملة التوريد والتركيب وعمل جميع ما يلزم لتثبيت وتشغيل المحطة وتدريب عدد 2 اثنان مهندسين أو فنيين بالموقع على أعمال التشغيل والصيانة.");

                column.Item()
                    .PaddingTop(5)
                    .Text(
                        $"قدرة النظام: {_quotation.SystemCapacity:N2} {_quotation.CapacityUnit}");
            });
    }

    // =========================
    // Items Table
    // =========================

    private void ComposeItemsTable(IContainer container)
    {
        container.Table(table =>
        {
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(35);
                columns.RelativeColumn(2);
                columns.RelativeColumn(3);
                columns.RelativeColumn(0.9f);
                columns.RelativeColumn(1.0f);
                columns.RelativeColumn(1.4f);
            });

            // Header
            table.Header(header =>
            {
                header.Cell()
                    .Element(HeaderCell)
                    .Text("م.");

                header.Cell()
                    .Element(HeaderCell)
                    .Text("البند");

                header.Cell()
                    .Element(HeaderCell)
                    .Text("تفاصيل البند");

                header.Cell()
                    .Element(HeaderCell)
                    .Text("العدد");

                header.Cell()
                    .Element(HeaderCell)
                    .Text("الوحدة");

                header.Cell()
                    .Element(HeaderCell)
                    .Text("بلد الصنع");
            });

            // Rows
            foreach (var item in _quotation.Items.OrderBy(x => x.SortOrder))
            {
                table.Cell()
                    .Element(BodyCell)
                    .Text(item.SortOrder.ToString());

                table.Cell()
                    .Element(BodyCell)
                    .Text(item.Item ?? "");

                table.Cell()
                    .Element(BodyCell)
                    .Text(item.Description ?? "");

                table.Cell()
                    .Element(BodyCell)
                    .Text(
                        item.Quantity?.ToString("N0") ?? "-");

                table.Cell()
                    .Element(BodyCell)
                    .Text(item.Unit ?? "-");

                table.Cell()
                    .Element(BodyCell)
                    .Text(item.CountryOfOrigin ?? "-");
            }
        });
    }

    // =========================
    // Table Header Style
    // =========================

    private static IContainer HeaderCell(IContainer container)
    {
        return container
            .Background("#159FA5")
            .Border(1)
            .BorderColor("#FFFFFF")
            .PaddingVertical(6)
            .PaddingHorizontal(4)
            .AlignCenter()
            .DefaultTextStyle(x => x.FontColor("#FFFFFF").Bold());
    }

    // =========================
    // Table Body Style
    // =========================

    private static IContainer BodyCell(IContainer container)
    {
        return container
            .Border(1)
            .BorderColor("#D6E7E8")
            .PaddingVertical(5)
            .PaddingHorizontal(4)
            .AlignCenter();
    }

    // =========================
    // Total
    // =========================

    private void ComposeTotal(IContainer container)
    {
        container
            .PaddingTop(8)
            .Background("#EAF7F7")
            .Border(2)
            .BorderColor("#159FA5")
            .Padding(15)
            .Column(column =>
            {
                column.Item()
                    .AlignCenter()
                    .Text("إجمالي قيمة العرض")
                    .Bold()
                    .FontSize(15)
                    .FontColor("#08777D");

                column.Item()
                    .PaddingTop(5)
                    .AlignCenter()
                    .Text($"{_quotation.TotalPrice:N0} جنيه مصري")
                    .Bold()
                    .FontSize(23)
                    .FontColor("#08777D");

                column.Item()
                    .PaddingTop(4)
                    .AlignCenter()
                    .Text($"{NumberToArabicWords(_quotation.TotalPrice)} جنيه مصري")
                    .Bold()
                    .FontSize(14)
                    .FontColor("#08777D");

                column.Item()
                    .PaddingTop(4)
                    .AlignCenter()
                    .Text(
                        "السعر شامل التوريد والنقل والتركيب والتشغيل حسب نطاق الأعمال.")
                    .FontSize(9);
            });
    }

    // =========================
    // Terms
    // =========================

    private void ComposeTerms(IContainer container)
    {
        container.Column(column =>
        {
            column.Item()
                .Text("الشروط العامة")
                .Bold()
                .FontSize(12)
                .FontColor("#08777D");

            if (!string.IsNullOrWhiteSpace(_quotation.GeneralTerms))
            {
                column.Item()
                    .PaddingTop(5)
                    .Text(_quotation.GeneralTerms!);
            }
            else
            {
                column.Item()
                    .PaddingTop(5)
                    .Column(terms =>
                    {
                        terms.Item().Text("• الأسعار تشمل التوريد والنقل والتركيب والتشغيل حسب نطاق الأعمال المتفق عليه.").FontSize(10);
                        terms.Item().PaddingTop(3).Text("• التصميم مبدئي ويمكن تعديله بعد المعاينة الفعلية للموقع، ويمكن تعديل السعر تبعاً لذلك.").FontSize(10);
                        terms.Item().PaddingTop(3).Text("• تأمين الموقع مسئولية العميل وليس شركة Red Sea Green Solutions.").FontSize(10);
                        terms.Item().PaddingTop(3).Text("• في حالة عدم توافر أي من المكونات يتم توفير ما يماثلها من حيث الجودة وفقاً لما هو متاح في السوق وبعد موافقة العميل.").FontSize(10);
                        terms.Item().PaddingTop(3).Text("• التركيب يكون خلال 15 يوماً من تاريخ التعاقد، ما لم يتم الاتفاق كتابياً على خلاف ذلك.").FontSize(10);

                        if (_quotation.Type == QuotationType.OnGrid)
                        {
                            terms.Item()
                                .PaddingTop(5)
                                .Text("ملحوظة: التكلفة لا تشمل رسوم العداد التبادلي.")
                                .Bold()
                                .FontSize(10);
                        }
                    });
            }

            if (!string.IsNullOrWhiteSpace(_quotation.PaymentTerms))
            {
                column.Item()
                    .PaddingTop(10)
                    .Text("شروط الدفع")
                    .Bold()
                    .FontSize(12)
                    .FontColor("#08777D");

                column.Item()
                    .PaddingTop(5)
                    .Text(_quotation.PaymentTerms!);
            }
            else
            {
                column.Item()
                    .PaddingTop(10)
                    .Text("شروط الدفع")
                    .Bold()
                    .FontSize(12)
                    .FontColor("#08777D");

                column.Item()
                    .PaddingTop(5)
                    .Column(payment =>
                    {
                        payment.Item().Text("• مقدم المحطة 70% عند التعاقد").FontSize(10);
                        payment.Item().PaddingTop(3).Text("• 20% عند التوريد").FontSize(10);
                        payment.Item().PaddingTop(3).Text("• 10% بعد التركيب والتسليم").FontSize(10);
                        payment.Item().PaddingTop(3).Text("• على أن تكون التحويلات بنكية.").FontSize(10);
                    });
            }

            if (!string.IsNullOrWhiteSpace(_quotation.Notes))
            {
                column.Item()
                    .PaddingTop(10)
                    .Text("ملاحظات")
                    .Bold()
                    .FontSize(12)
                    .FontColor("#08777D");

                column.Item()
                    .PaddingTop(4)
                    .Text(_quotation.Notes!);
            }
        });
    }

    // ========================
    // Stamp 
    // ========================

    private void ComposeStamp(IContainer container)
    {
        container
            .PaddingTop(15)
            .AlignLeft()
            .Column(column =>
            {
                column.Item()
                    .PaddingTop(5)
                    .Width(200)
                    .Image(GetAssetPath("stamp.png"))
                    .FitWidth();
            });
    }

    // =========================
    // Footer
    // =========================

    private void ComposeFooter(IContainer container)
    {
        container
            .MinHeight(58)
            .Column(column =>
            {
                // Top brand line
                column.Item()
                    .Height(3)
                    .Background("#159FA5");

                column.Item()
                    .PaddingTop(7)
                    .PaddingHorizontal(6)
                    .Row(row =>
                    {
                        // =====================================================
                        // RIGHT — COMPANY ADDRESS
                        // =====================================================
                        row.RelativeItem(2.75f)
                            .AlignRight()
                            .Column(address =>
                            {
                                address.Item()
                                    .Row(addressRow =>
                                    {

                                        addressRow.RelativeItem()
                                            .AlignRight()
                                            .ScaleToFit()
                                            .Text(
                                                "المقر : الدور الأول أوريم مول - أمام الجامعة الفرنسية - الشروق – القاهرة.")
                                            .FontSize(8.5f);

                                    });

                                address.Item()
                                    .PaddingTop(6)
                                    .ScaleToFit()
                                    .AlignRight()
                                    .Text(
                                        "الفرع : أمام البنك الزراعي - موط - صحراء الواحات الداخله - الوادي الجديد.")
                                    .FontSize(8f);
                            });

                        // Divider
                        row.ConstantItem(1)
                            .Height(38)
                            .Background("#D9EDEE");

                        row.ConstantItem(3);

                        // =====================================================
                        // CENTER — PHONE NUMBERS
                        // =====================================================
                        row.RelativeItem(1.45f)
                            .AlignCenter()
                            .Column(phones =>
                            {
                                phones.Item()
                                    .Row(phoneRow =>
                                    {
                                        phoneRow.RelativeItem()
                                            .AlignLeft()
                                            .PaddingLeft(4)
                                            .ContentFromLeftToRight()
                                            .Text("(+20) 15 5553 8054")
                                            .FontSize(10)
                                            .LineHeight(1.1f);

                                        phoneRow.ConstantItem(19)
                                            .Height(19)
                                            .PaddingLeft(3)
                                            .Svg(GetAssetPath("phone.svg"))
                                            .FitArea();
                                    });

                                phones.Item()
                                    .PaddingTop(6)
                                    .Row(phoneRow =>
                                    {
                                        phoneRow.RelativeItem()
                                            .AlignLeft()
                                            .PaddingLeft(4)
                                            .ContentFromLeftToRight()
                                            .Text("(+20) 10 1880 3465")
                                            .FontSize(10)
                                            .LineHeight(1.1f);

                                        phoneRow.ConstantItem(19)
                                            .Height(19)
                                            .PaddingLeft(3)
                                            .Svg(GetAssetPath("phone.svg"))
                                            .FitArea();
                                    });
                            });

                        // Divider
                        row.ConstantItem(1)
                            .Height(38)
                            .Background("#D9EDEE");

                        row.ConstantItem(5);

                        // =====================================================
                        // LEFT — WEBSITE / EMAIL
                        // =====================================================
                        row.RelativeItem(1.35f)
                            .AlignLeft()
                            .Column(contact =>
                            {
                                contact.Item()
                                    .Row(contactRow =>
                                    {
                                        contactRow.RelativeItem()
                                            .AlignLeft()
                                            .PaddingLeft(4)
                                            .Text("www.rsgs-egy.com")
                                            .FontSize(10)
                                            .LineHeight(1.1f);

                                        contactRow.ConstantItem(19)
                                            .Height(19)
                                            .PaddingLeft(3)
                                            .Svg(GetAssetPath("website.svg"))
                                            .FitArea();
                                    });

                                contact.Item()
                                    .PaddingTop(6)
                                    .Row(contactRow =>
                                    {
                                        contactRow.RelativeItem()
                                            .AlignLeft()
                                            .PaddingLeft(4)
                                            .Text("info@rsgs-egy.com")
                                            .FontSize(10)
                                            .LineHeight(1.1f);

                                        contactRow.ConstantItem(19)
                                            .Height(19)
                                            .PaddingLeft(3)
                                            .Svg(GetAssetPath("mail.svg"))
                                            .FitArea();
                                    });
                            });
                    });
            });
    }

    // =========================
    // Number To Arabic Words
    // =========================

    private static string NumberToArabicWords(decimal number)
    {
        if (number == 0)
            return "صفر";

        if (number < 0)
            return "سالب " + NumberToArabicWords(Math.Abs(number));

        long value = (long)Math.Round(number);

        return ConvertArabicNumber(value).Trim();
    }

    private static string ConvertArabicNumber(long number)
    {
        if (number < 1000)
            return ConvertBelowThousand(number);

        if (number < 1_000_000)
        {
            long thousands = number / 1000;
            long remainder = number % 1000;

            string result = thousands switch
            {
                1 => "ألف",
                2 => "ألفان",
                >= 3 and <= 10 => ConvertBelowThousand(thousands) + " آلاف",
                _ => ConvertBelowThousand(thousands) + " ألف"
            };

            if (remainder > 0)
                result += " و" + ConvertBelowThousand(remainder);

            return result;
        }

        if (number < 1_000_000_000)
        {
            long millions = number / 1_000_000;
            long remainder = number % 1_000_000;

            string result = millions switch
            {
                1 => "مليون",
                2 => "مليونان",
                >= 3 and <= 10 => ConvertBelowThousand(millions) + " ملايين",
                _ => ConvertArabicNumber(millions) + " مليون"
            };

            if (remainder > 0)
                result += " و" + ConvertArabicNumber(remainder);

            return result;
        }

        long billions = number / 1_000_000_000;
        long rest = number % 1_000_000_000;

        string billionResult = billions switch
        {
            1 => "مليار",
            2 => "ملياران",
            >= 3 and <= 10 => ConvertBelowThousand(billions) + " مليارات",
            _ => ConvertArabicNumber(billions) + " مليار"
        };

        if (rest > 0)
            billionResult += " و" + ConvertArabicNumber(rest);

        return billionResult;
    }

    private static string ConvertBelowThousand(long number)
    {
        if (number == 0)
            return "";

        string[] ones =
        {
        "",
        "واحد",
        "اثنان",
        "ثلاثة",
        "أربعة",
        "خمسة",
        "ستة",
        "سبعة",
        "ثمانية",
        "تسعة"
    };

        string[] tens =
        {
        "",
        "",
        "عشرون",
        "ثلاثون",
        "أربعون",
        "خمسون",
        "ستون",
        "سبعون",
        "ثمانون",
        "تسعون"
    };

        string[] hundreds =
        {
        "",
        "مائة",
        "مائتان",
        "ثلاثمائة",
        "أربعمائة",
        "خمسمائة",
        "ستمائة",
        "سبعمائة",
        "ثمانمائة",
        "تسعمائة"
    };

        var parts = new List<string>();

        long hundred = number / 100;
        long remainder = number % 100;

        if (hundred > 0)
            parts.Add(hundreds[hundred]);

        if (remainder > 0)
        {
            if (remainder < 10)
            {
                parts.Add(ones[remainder]);
            }
            else if (remainder == 10)
            {
                parts.Add("عشرة");
            }
            else if (remainder == 11)
            {
                parts.Add("أحد عشر");
            }
            else if (remainder == 12)
            {
                parts.Add("اثنا عشر");
            }
            else if (remainder < 20)
            {
                parts.Add(ones[remainder - 10] + " عشر");
            }
            else
            {
                long one = remainder % 10;
                long ten = remainder / 10;

                if (one > 0)
                    parts.Add(ones[one] + " و" + tens[ten]);
                else
                    parts.Add(tens[ten]);
            }
        }

        return string.Join(" و", parts);
    }


    // =========================
    // Quotation Type
    // =========================

    private static string GetQuotationTypeName(QuotationType type)
    {
        return type switch
        {
            QuotationType.OnGrid => "On-Grid",
            QuotationType.OffGrid => "Off-Grid",
            QuotationType.SolarPump => "Solar Pump",
            _ => "غير محدد"
        };
    }
}