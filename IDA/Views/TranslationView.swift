import SwiftUI

struct TranslationView: View {
    @StateObject private var manager = TranslationManager()
    @State private var showAddSheet = false
    @State private var newOriginal = ""
    @State private var newTranslated = ""
    @State private var showDeleteConfirm = false
    @State private var itemToDelete: String?
    @State private var showEditSheet = false
    @State private var editingOriginal = ""
    @State private var editingTranslated = ""

    var body: some View {
        VStack(spacing: 0) {

            topStatsView

            searchBar

            translationList
        }
        .sheet(isPresented: $showAddSheet) {
            addTranslationSheet
        }
        .sheet(isPresented: $showEditSheet) {
            editTranslationSheet
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let key = itemToDelete {
                    manager.deleteTranslation(original: key)
                }
                itemToDelete = nil
            }
        } message: {
            if let key = itemToDelete {
                Text("确定要删除翻译条目吗？\n\n\"\(key)\"")
            }
        }
    }

    private var topStatsView: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "总条目",
                value: "\(manager.totalCount)",
                icon: "book.fill"
            )

            StatCard(
                title: "已翻译",
                value: "\(manager.translatedCount)",
                icon: "checkmark.circle.fill"
            )

            StatCard(
                title: "自定义",
                value: "\(manager.customCount)",
                icon: "star.fill"
            )

            Spacer()

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    IDAColorfulIcon(systemName: "plus.circle.fill", size: 14)
                    Text("添加翻译")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.3, blue: 0.3),
                            Color(red: 1.0, green: 0.6, blue: 0.1),
                            Color(red: 0.3, green: 0.6, blue: 1.0),
                            Color(red: 0.7, green: 0.3, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var searchBar: some View {
        HStack {
            IDAColorfulIcon(systemName: "magnifyingglass", size: 14)

            TextField("搜索原文或译文...", text: $manager.searchText)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !manager.searchText.isEmpty {
                Button {
                    manager.searchText = ""
                } label: {
                    IDAColorfulIcon(systemName: "xmark.circle.fill", size: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var translationList: some View {
        Group {
            if manager.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.filteredTranslations.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(manager.filteredTranslations, id: \.key) { item in
                            TranslationRow(
                                original: item.key,
                                translated: item.value,
                                isCustom: manager.isCustomTranslation(item.key),
                                onEdit: {
                                    editingOriginal = item.key
                                    editingTranslated = item.value
                                    showEditSheet = true
                                },
                                onDelete: {
                                    itemToDelete = item.key
                                    showDeleteConfirm = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            IDAColorfulIcon(systemName: "magnifyingglass", size: 36)

            Text("未找到匹配的翻译")
                .font(.system(size: 16, weight: .medium))

            Text(manager.searchText.isEmpty ? "点击上方按钮添加新翻译" : "尝试使用其他关键词搜索")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addTranslationSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("添加新翻译")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    showAddSheet = false
                } label: {
                    IDAColorfulIcon(systemName: "xmark.circle.fill", size: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("原文（英文）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $newOriginal)
                        .font(.system(size: 14))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("译文（中文）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $newTranslated)
                        .font(.system(size: 14))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                HStack {
                    Spacer()

                    Button {
                        showAddSheet = false
                        newOriginal = ""
                        newTranslated = ""
                    } label: {
                        Text("取消")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.15))
                            )
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if manager.addTranslation(original: newOriginal, translated: newTranslated) {
                            showAddSheet = false
                            newOriginal = ""
                            newTranslated = ""
                        }
                    } label: {
                        Text("保存")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(newOriginal.isEmpty || newTranslated.isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var editTranslationSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("编辑翻译")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    showEditSheet = false
                } label: {
                    IDAColorfulIcon(systemName: "xmark.circle.fill", size: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("原文（英文）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $editingOriginal)
                        .font(.system(size: 14))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("译文（中文）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    TextEditor(text: $editingTranslated)
                        .font(.system(size: 14))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                }

                HStack {
                    Spacer()

                    Button {
                        showEditSheet = false
                    } label: {
                        Text("取消")
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.15))
                            )
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        if manager.updateTranslation(original: editingOriginal, newTranslated: editingTranslated) {
                            showEditSheet = false
                        }
                    } label: {
                        Text("保存修改")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(editingOriginal.isEmpty || editingTranslated.isEmpty)
                }
            }
            .padding(20)
        }
        .frame(width: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                IDAColorfulIcon(systemName: icon, size: 12)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

struct TranslationRow: View {
    let original: String
    let translated: String
    let isCustom: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            VStack {
                if isCustom {
                    IDAColorfulIcon(systemName: "star.fill", size: 12)
                }
                Spacer()
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 6) {
                Text(original)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(translated)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        IDAColorfulIcon(systemName: "pencil.line", size: 14)
                    }
                    .buttonStyle(.plain)

                    if isCustom {
                        Button(action: onDelete) {
                            IDAColorfulIcon(systemName: "trash.fill", size: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}
