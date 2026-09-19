import Foundation
import Observation

/// Category food-type discovery: outlets serving the category + their dishes.
/// Never routes to Search; sections only exist for outlets with matching
/// available dishes (guaranteed by the repository).
@MainActor
@Observable
final class CategoryResultsViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([CategoryOutlet])
        case empty
        case error(message: String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.empty, .empty): return true
            case (.loaded(let a), .loaded(let b)): return a == b
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    /// Client-side diet filter over loaded dishes (real data only).
    enum DietFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case veg = "Veg"
        case nonVeg = "Non-Veg"
        var id: String { rawValue }
    }

    private(set) var state: State = .idle
    var dietFilter: DietFilter = .all
    var under100Only = false

    let category: FoodCategory
    private let repository: AppRepository
    private var allSections: [CategoryOutlet] = []

    init(category: FoodCategory, repository: AppRepository) {
        self.category = category
        self.repository = repository
    }

    /// Sections after client filters. An outlet section survives only while
    /// it still has visible dishes.
    var visibleSections: [CategoryOutlet] {
        guard case .loaded = state else { return [] }
        return allSections.compactMap { section in
            var dishes = section.dishes
            switch dietFilter {
            case .all: break
            case .veg: dishes = dishes.filter(\.isVeg)
            case .nonVeg: dishes = dishes.filter { !$0.isVeg }
            }
            if under100Only { dishes = dishes.filter { $0.price < 100 } }
            guard !dishes.isEmpty else { return nil }
            var copy = section
            copy.dishes = dishes
            return copy
        }
    }

    var dishCount: Int { allSections.reduce(0) { $0 + $1.dishCount } }

    func load() async {
        guard case .idle = state else { return }
        state = .loading
        do {
            let sections = try await repository.food.getOutletsForCategory(category.id, categoryName: category.name)
            allSections = sections
            state = sections.isEmpty ? .empty : .loaded(sections)
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }

    func refresh() async {
        state = .idle
        await load()
    }
}
