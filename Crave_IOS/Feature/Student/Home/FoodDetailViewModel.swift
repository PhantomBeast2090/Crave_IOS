import Foundation
import Observation

@MainActor
@Observable
final class FoodDetailViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(FoodItem)
        case error(message: String)
    }
    
    private(set) var state: State = .idle
    private let repository: AppRepository
    let foodId: String
    
    init(foodId: String, repository: AppRepository) {
        self.foodId = foodId
        self.repository = repository
    }
    
    func load() async {
        guard case .idle = state else { return }
        state = .loading
        
        do {
            let item = try await repository.food.getFoodById(foodId)
            state = .loaded(item)
        } catch is CancellationError {
            // Task was cancelled (e.g. view re-rendered mid-load).
            // Reset so a retry can run; never surface this as an error.
            state = .idle
        } catch {
            state = .error(message: error.localizedDescription)
        }
    }
    
    func refresh() async {
        state = .idle
        await load()
    }
    
    func toggleFavorite() async {
        guard case .loaded(var item) = state else { return }
        do {
            let newStatus = try await repository.food.toggleFavorite(foodItemId: item.id)
            item.isFavorite = newStatus
            state = .loaded(item)
        } catch {
            print("Failed to toggle favorite: \(error)")
        }
    }
}
