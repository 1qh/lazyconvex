import ConvexCore
import DesktopShared
import Foundation
import SwiftCrossUI

internal enum FormMode {
    case create
    case edit(Blog)
}

internal final class FormViewModel: SwiftCrossUI.ObservableObject, Performing {
    @SwiftCrossUI.Published var title = ""
    @SwiftCrossUI.Published var content = ""
    @SwiftCrossUI.Published var category = BlogCategory.tech
    @SwiftCrossUI.Published var published = false
    @SwiftCrossUI.Published var isSaving = false
    @SwiftCrossUI.Published var errorMessage: String?

    let mode: FormMode

    var isValid: Bool {
        !title.trimmed.isEmpty &&
            content.trimmed.count >= 3
    }

    init(mode: FormMode) {
        self.mode = mode
        if case let .edit(blog) = mode {
            title = blog.title
            content = blog.content
            category = blog.category
            published = blog.published
        }
    }

    @MainActor
    func save(onDone: () -> Void) async {
        guard isValid else {
            return
        }

        await performLoading({ isSaving = $0 }) {
            switch mode {
            case .create:
                try await BlogAPI.create(
                    client,
                    category: category,
                    content: content.trimmed,
                    published: published,
                    title: title.trimmed
                )

            case let .edit(blog):
                try await BlogAPI.update(
                    client,
                    id: blog._id,
                    category: category,
                    content: content.trimmed,
                    published: published,
                    title: title.trimmed,
                    expectedUpdatedAt: blog.updatedAt
                )
            }
            onDone()
        }
    }
}

internal struct FormView: View {
    let onDone: () -> Void
    @State private var viewModel: FormViewModel

    var body: some View {
        VStack {
            Text(isEditMode ? "Edit Post" : "New Post")
                .padding(.bottom, 8)

            TextField("Title", text: $viewModel.title)
            TextField("Content", text: $viewModel.content)
            HStack {
                ForEach(0..<BlogCategory.allCases.count, id: \.self) { idx in
                    let cat = BlogCategory.allCases[idx]
                    Button(cat.displayName) {
                        viewModel.category = cat
                    }
                }
            }

            Toggle("Published", isOn: $viewModel.published)

            if let msg = viewModel.errorMessage {
                Text(msg)
                    .foregroundColor(.red)
            }

            HStack {
                Button("Cancel") {
                    onDone()
                }
                Button(isEditMode ? "Save" : "Create") {
                    Task { await viewModel.save(onDone: onDone) }
                }
            }
            .padding(.top, 4)

            if viewModel.isSaving {
                Text("Saving...")
            }
        }
    }

    // swiftlint:disable:next type_contents_order
    init(mode: FormMode, onDone: @escaping () -> Void) {
        self.onDone = onDone
        _viewModel = State(wrappedValue: FormViewModel(mode: mode))
    }

    private var isEditMode: Bool {
        if case .edit = viewModel.mode {
            return true
        }
        return false
    }
}
