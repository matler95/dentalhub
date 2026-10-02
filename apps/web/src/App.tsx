import { Inbox } from "./features/inbox/Inbox";

export default function App() {
  return (
    <>
      <div role="status" className="bg-ink px-4 py-2 text-center text-sm text-white">
        Tryb testowy: nie wysyłaj plików z danymi pacjentów.
      </div>
      <Inbox />
    </>
  );
}
