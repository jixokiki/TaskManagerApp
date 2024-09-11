import SwiftUI
#if canImport(MessageUI)
import MessageUI
#endif

// Model data untuk tugas
enum TaskStatus: String, Codable {
    case toDo = "To Do"
    case inProgress = "In Progress"
    case done = "Done"
}

struct Task: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date = Date()
    var status: TaskStatus = .toDo
    var recipientEmail: String = "" // Tambahkan properti ini untuk menyimpan email per tugas
}

// ViewModel untuk menangani logika tugas
class TaskViewModel: ObservableObject {
    @Published var tasks: [Task] = [] {
        didSet {
            saveTasks()
        }
    }
    
    private let tasksKey = "tasksKey"

    init() {
        loadTasks()
    }

    // Menambahkan tugas baru
    func addTask(title: String, dueDate: Date) {
        let newTask = Task(title: title, dueDate: dueDate)
        tasks.append(newTask)
    }

    // Menghapus tugas
    func deleteTask(at offsets: IndexSet) {
        tasks.remove(atOffsets: offsets)
    }

    // Menandai tugas sebagai selesai
    func toggleCompletion(task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            if tasks[index].isCompleted {
                tasks[index].status = .done
            }
        }
    }
    
    // Mengubah status tugas
    func changeStatus(task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            switch tasks[index].status {
            case .toDo:
                tasks[index].status = .inProgress
            case .inProgress:
                tasks[index].status = .done
            default:
                break
            }
        }
    }

    // Menyimpan tugas ke UserDefaults
    func saveTasks() {
        if let encodedData = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encodedData, forKey: tasksKey)
        }
    }

    // Memuat tugas dari UserDefaults
    func loadTasks() {
        if let savedData = UserDefaults.standard.data(forKey: tasksKey),
           let decodedTasks = try? JSONDecoder().decode([Task].self, from: savedData) {
            tasks = decodedTasks
        }
    }
}

// Tampilan utama dengan SwiftUI
struct ContentView: View {
    @StateObject var taskViewModel = TaskViewModel()
    @State private var newTaskTitle = ""
    @State private var selectedDueDate = Date()
    @State private var showingMailView = false
    @State private var emailData: EmailData?

    var body: some View {
        let taskList = taskViewModel.tasks
        
        return VStack {
            HStack {
                TextField("Masukkan tugas baru", text: $newTaskTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                DatePicker("", selection: $selectedDueDate, displayedComponents: .date)
                    .labelsHidden()

                Button(action: {
                    guard !newTaskTitle.isEmpty else { return }
                    taskViewModel.addTask(title: newTaskTitle, dueDate: selectedDueDate)
                    newTaskTitle = ""
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                }
                .padding(.trailing)
            }

            List {
                ForEach(taskList) { task in
                    taskRow(for: task)
                }
                .onDelete(perform: taskViewModel.deleteTask)
            }
        }
        .padding()
        .sheet(isPresented: $showingMailView) {
            if let emailData = emailData {
                #if os(iOS)
                MailView(data: emailData) { result in
                    print(result)
                }
                #endif
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Manajemen Tugas")
                    .font(.headline)
            }
        }
    }
    
    func taskRow(for task: Task) -> some View {
        VStack {
            HStack {
                Button(action: {
                    taskViewModel.toggleCompletion(task: task)
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(BorderlessButtonStyle())

                VStack(alignment: .leading) {
                    Text(task.title)
                        .strikethrough(task.isCompleted, color: .black)
                        .foregroundColor(task.status == .done ? .white : .primary)

                    Text("Due: \(task.dueDate, formatter: taskDateFormatter)")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    if task.status == .toDo {
                        Button("Select To Do") {
                            taskViewModel.changeStatus(task: task)
                        }
                        .padding(5)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }

                    if task.status == .done {
                        // Input email khusus untuk tugas ini
                        TextField("Masukkan email tujuan", text: Binding(
                            get: { task.recipientEmail },
                            set: { taskViewModel.tasks[taskViewModel.tasks.firstIndex(where: { $0.id == task.id })!].recipientEmail = $0 }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.black)
                        .padding(.bottom, 5)

                        Button("Kirim Tugas via Email") {
                            sendEmail(for: task)
                        }
                        .padding(5)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(
                    task.status == .inProgress ? Color.blue : (task.status == .done ? Color.green : Color.clear)
                )
                .foregroundColor(task.status == .inProgress ? .white : (task.status == .done ? .white : .primary))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(task.status == .inProgress ? Color.lightBlue : Color.clear, lineWidth: 2)
                )
            }
        }
    }

    func sendEmail(for task: Task) {
        let startDate = task.dueDate
        let endDate = Date()

        let formattedDueDate = taskDateFormatter.string(from: task.dueDate)
        let formattedEndDate = taskDateFormatter.string(from: endDate)

        let emailBody = """
        Nama Tugas: \(task.title)
        Tanggal Pengerjaan: \(formattedDueDate)
        Tanggal Selesai: \(formattedEndDate)
        """

        #if os(iOS)
        emailData = EmailData(subject: "Laporan Tugas Selesai", recipients: [task.recipientEmail], body: emailBody)
        showingMailView.toggle()
        #elseif os(macOS)
        openEmailApp(for: task, subject: "Laporan Tugas Selesai", body: emailBody)
        #endif
    }

    func openEmailApp(for task: Task, subject: String, body: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

        let mailtoURL = "mailto:\(task.recipientEmail)?subject=\(encodedSubject)&body=\(encodedBody)"
        let gmailWebURL = "https://mail.google.com/mail/?view=cm&fs=1&to=\(task.recipientEmail)&su=\(encodedSubject)&body=\(encodedBody)"
        
        // Membuka Gmail di browser
        if let gmailWebURL = URL(string: gmailWebURL) {
            NSWorkspace.shared.open(gmailWebURL) // Buka Gmail di browser
        } else if let mailAppURL = URL(string: mailtoURL) {
            NSWorkspace.shared.open(mailAppURL)
        }
    }
}

// Formatter untuk menampilkan tanggal
private let taskDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()

extension Color {
    static let lightBlue = Color(red: 0.67, green: 0.84, blue: 0.90)
}

// Struktur untuk menampung data email
struct EmailData {
    var subject: String
    var recipients: [String]
    var body: String
}

// UIViewController untuk menampilkan MailComposer di SwiftUI untuk iOS
#if os(iOS)
struct MailView: UIViewControllerRepresentable {
    let data: EmailData
    let callback: (Result<MFMailComposeResult, Error>) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setSubject(data.subject)
        vc.setToRecipients(data.recipients)
        vc.setMessageBody(data.body, isHTML: false)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(callback: callback)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let callback: (Result<MFMailComposeResult, Error>) -> Void

        init(callback: @escaping (Result<MFMailComposeResult, Error>) -> Void) {
            self.callback = callback
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                callback(.failure(error))
            } else {
                callback(.success(result))
            }
            controller.dismiss(animated: true)
        }
    }
}
#endif

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
