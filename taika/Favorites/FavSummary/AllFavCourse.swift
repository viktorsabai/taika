import SwiftUI

private typealias T = PD

struct AllFavCourseView: View {
    let courses: [FDCourseDTO]

    @Environment(\.dismiss) private var dismiss
    @State private var route: CourseRoute? = nil

    private struct CourseRoute: Identifiable, Hashable {
        let id = UUID()
        let courseId: String
    }

    var body: some View {
        ZStack {
            T.ColorToken.background.ignoresSafeArea()
            VStack(spacing: 10) {
                AppBackHeader { dismiss() }
                HStack {
                    Text("Курсы")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(courses.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, PD.Spacing.screen)

                if courses.isEmpty {
                    VStack(spacing: 10) {
                        TaikaEmptyStateIcon(systemName: "graduationcap", size: 28)
                        Text("Нет избранных курсов")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(courses, id: \.courseId) { dto in
                                FDFavCourseCard(
                                    item: dto,
                                    onOpen: { route = CourseRoute(courseId: dto.courseId) },
                                    onUnfavorite: nil
                                )
                            }
                        }
                        .padding(.horizontal, PD.Spacing.screen)
                        .padding(.bottom, ToolBar.recommendedBottomInset)
                    }
                }
            }
        }
        .navigationDestination(item: $route) { r in
            LessonsView(courseId: r.courseId)
                .toolbar(.hidden, for: .navigationBar)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationView {
        AllFavCourseView(courses: [])
    }
}
