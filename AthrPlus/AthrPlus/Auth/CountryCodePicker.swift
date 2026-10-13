//
//  CountryCodePicker.swift
//  AthrPlus
//
//  Searchable country code picker sheet for Athr+ authentication.
//

import SwiftUI

/// Represents an international country dialing code.
public struct CountryCode: Identifiable, Hashable, Equatable, Sendable {
    public let id: String // ISO 3166-1 alpha-2 code
    public let name: String
    public let dialCode: String
    public let flag: String
    public let expectedPhoneLength: Int

    public init(id: String, name: String, dialCode: String, flag: String, expectedPhoneLength: Int = 10) {
        self.id = id
        self.name = name
        self.dialCode = dialCode
        self.flag = flag
        self.expectedPhoneLength = expectedPhoneLength
    }

    /// Default country code: India (+91)
    public static let india = CountryCode(
        id: "IN",
        name: "India",
        dialCode: "+91",
        flag: "🇮🇳",
        expectedPhoneLength: 10
    )

    public static let allCountries: [CountryCode] = [
        CountryCode(id: "IN", name: "India", dialCode: "+91", flag: "🇮🇳", expectedPhoneLength: 10),
        CountryCode(id: "US", name: "United States", dialCode: "+1", flag: "🇺🇸", expectedPhoneLength: 10),
        CountryCode(id: "GB", name: "United Kingdom", dialCode: "+44", flag: "🇬🇧", expectedPhoneLength: 10),
        CountryCode(id: "AE", name: "United Arab Emirates", dialCode: "+971", flag: "🇦🇪", expectedPhoneLength: 9),
        CountryCode(id: "SG", name: "Singapore", dialCode: "+65", flag: "🇸🇬", expectedPhoneLength: 8),
        CountryCode(id: "AU", name: "Australia", dialCode: "+61", flag: "🇦🇺", expectedPhoneLength: 9),
        CountryCode(id: "CA", name: "Canada", dialCode: "+1", flag: "🇨🇦", expectedPhoneLength: 10),
        CountryCode(id: "DE", name: "Germany", dialCode: "+49", flag: "🇩🇪", expectedPhoneLength: 10),
        CountryCode(id: "FR", name: "France", dialCode: "+33", flag: "🇫🇷", expectedPhoneLength: 9),
        CountryCode(id: "NL", name: "Netherlands", dialCode: "+31", flag: "🇳🇱", expectedPhoneLength: 9),
        CountryCode(id: "ES", name: "Spain", dialCode: "+34", flag: "🇪🇸", expectedPhoneLength: 9),
        CountryCode(id: "IT", name: "Italy", dialCode: "+39", flag: "🇮🇹", expectedPhoneLength: 10),
        CountryCode(id: "JP", name: "Japan", dialCode: "+81", flag: "🇯🇵", expectedPhoneLength: 10),
        CountryCode(id: "KR", name: "South Korea", dialCode: "+82", flag: "🇰🇷", expectedPhoneLength: 10),
        CountryCode(id: "MY", name: "Malaysia", dialCode: "+60", flag: "🇲🇾", expectedPhoneLength: 9),
        CountryCode(id: "ID", name: "Indonesia", dialCode: "+62", flag: "🇮🇩", expectedPhoneLength: 10),
        CountryCode(id: "SA", name: "Saudi Arabia", dialCode: "+966", flag: "🇸🇦", expectedPhoneLength: 9),
        CountryCode(id: "QA", name: "Qatar", dialCode: "+974", flag: "🇶🇦", expectedPhoneLength: 8),
        CountryCode(id: "NZ", name: "New Zealand", dialCode: "+64", flag: "🇳🇿", expectedPhoneLength: 9),
        CountryCode(id: "IE", name: "Ireland", dialCode: "+353", flag: "🇮🇪", expectedPhoneLength: 9),
        CountryCode(id: "CH", name: "Switzerland", dialCode: "+41", flag: "🇨🇭", expectedPhoneLength: 9),
        CountryCode(id: "TH", name: "Thailand", dialCode: "+66", flag: "🇹🇭", expectedPhoneLength: 9),
        CountryCode(id: "VN", name: "Vietnam", dialCode: "+84", flag: "🇻🇳", expectedPhoneLength: 9),
        CountryCode(id: "BR", name: "Brazil", dialCode: "+55", flag: "🇧🇷", expectedPhoneLength: 11),
        CountryCode(id: "ZA", name: "South Africa", dialCode: "+27", flag: "🇿🇦", expectedPhoneLength: 9)
    ]
}

/// A searchable modal sheet view for selecting an international country dialing code.
public struct CountryCodePickerView: View {
    @Binding public var selectedCountry: CountryCode
    public var onSelect: ((CountryCode) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    public init(
        selectedCountry: Binding<CountryCode>,
        onSelect: ((CountryCode) -> Void)? = nil
    ) {
        self._selectedCountry = selectedCountry
        self.onSelect = onSelect
    }

    private var filteredCountries: [CountryCode] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return CountryCode.allCountries
        }

        let digitsOnly = query.filter { $0.isNumber }

        return CountryCode.allCountries.filter { country in
            let nameMatches = country.name.lowercased().contains(query)
            let isoMatches = country.id.lowercased().contains(query)
            let dialMatches = country.dialCode.lowercased().contains(query)
            let digitsMatch = !digitsOnly.isEmpty && country.dialCode.contains(digitsOnly)
            return nameMatches || isoMatches || dialMatches || digitsMatch
        }
    }

    public var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCountries) { country in
                    Button {
                        selectedCountry = country
                        onSelect?(country)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Text(country.flag)
                                .font(.system(size: 28))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(country.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                Text(country.id)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(country.dialCode)
                                .font(.callout.monospacedDigit())
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(6)

                            if selectedCountry.id == country.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                                    .font(.subheadline.bold())
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(country.name), code \(country.dialCode)")
                    .accessibilityAddTraits(selectedCountry.id == country.id ? [.isSelected, .isButton] : [.isButton])
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search by country or code"
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    CountryCodePickerView(selectedCountry: .constant(CountryCode.india))
}
