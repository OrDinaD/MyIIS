import SwiftUI

struct EmployeeProfileView: View {
    let hit: EmployeeSearchHit
    @State private var viewModel = EmployeeProfileViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView("Загрузка профиля...")
                    Spacer()
                }
            } else if let error = viewModel.error {
                ContentUnavailableView("Ошибка", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
            } else if let profile = viewModel.profile {
                Section {
                    HStack(spacing: 16) {
                        if let url = profile.photoURL {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                case .failure(_), .empty:
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .foregroundStyle(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 88, height: 88)
                                .foregroundStyle(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name.getFullName())
                                .font(.title3.bold())
                            
                            if let degree = profile.degreeAbbreviation {
                                Text(degree)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let rank = profile.rank {
                                Text(rank)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if let email = profile.email, !email.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "envelope.fill").foregroundStyle(.blue)
                            Text(email)
                        }
                    }
                }
                
                if !profile.positions.isEmpty {
                    Section("Должности") {
                        ForEach(profile.positions, id: \.self) { pos in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pos.title).font(.headline)
                                Text(pos.departmentName).font(.subheadline).foregroundStyle(.secondary)
                                
                                ForEach(pos.contacts, id: \.self) { contact in
                                    if let phone = contact.phone {
                                        HStack {
                                            Image(systemName: "phone.fill").foregroundStyle(.green).font(.caption)
                                            Text(phone).font(.subheadline)
                                        }
                                    }
                                    if let addr = contact.address {
                                        HStack(alignment: .top) {
                                            Image(systemName: "mappin.and.ellipse").foregroundStyle(.red).font(.caption)
                                            Text(addr).font(.subheadline)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                if !profile.readingCourses.isEmpty {
                    Section("Читаемые курсы") {
                        ForEach(profile.readingCourses, id: \.self) { course in
                            Text(course)
                        }
                    }
                }
                
                if !profile.additionalSections.isEmpty {
                    ForEach(profile.additionalSections) { section in
                        Section(section.title) {
                            if let attributed = try? NSAttributedString(data: Data(section.htmlContent.utf8), options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue], documentAttributes: nil) {
                                Text(AttributedString(attributed))
                            } else {
                                Text(section.htmlContent)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(hit.fio)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(for: hit)
        }
    }
}
