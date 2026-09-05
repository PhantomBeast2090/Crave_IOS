import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum State: Equatable {
        case idle
        case loading
        case results([FoodItem])
        case error(String)
    }
    
    private(set) var state: State = .idle
    private let repository: AppRepository
    var filter = FoodSearchFilter()
    private var searchTask: Task<Void, Never>?
    
    init(repository: AppRepository) {
        self.repository = repository
    }
    
    func updateQuery(_ query: String) {
        filter.query = query
        debouncedSearch()
    }
    
    func updateFilter(_ newFilter: FoodSearchFilter) {
        filter = newFilter
        searchTask?.cancel()
        searchTask = Task { await performSearch() }
    }
    
    private func debouncedSearch() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            if !Task.isCancelled {
                await performSearch()
            }
        }
    }
    
    func performSearch() async {
        guard !filter.query.isEmpty || filter.outletId != nil || filter.category != nil || filter.isVeg != nil || filter.maxPrice != nil else {
            state = .idle
            return
        }
        
        state = .loading
        
        do {
            let results = try await repository.food.searchFood(filter: filter)
            if !Task.isCancelled {
                state = .results(results)
            }
        } catch {
            if !Task.isCancelled {
                state = .error(error.localizedDescription)
            }
        }
    }
    
    func clear() {
        filter = FoodSearchFilter()
        state = .idle
    }
}
