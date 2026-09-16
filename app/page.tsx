import NutritionTracker from "@/components/NutritionTracker";

export default function Home() {
  return (
    <main className="mx-auto flex max-w-3xl flex-col gap-8 px-4 py-10">
      <header className="flex flex-col gap-2">
        <h1 className="text-3xl font-bold tracking-tight text-emerald-600 dark:text-emerald-400">
          Nutrition Tracker
        </h1>
        <p className="text-sm text-slate-500 dark:text-slate-400">
          Log what you eat and keep an eye on your calories and macros.
        </p>
      </header>
      <NutritionTracker />
    </main>
  );
}
