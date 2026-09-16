"use client";

import { useEffect, useMemo, useState } from "react";
import { MEALS, type Meal } from "@/lib/meals";
import type { FoodEntry, Totals } from "@/lib/types";

const EMPTY_FORM = {
  name: "",
  meal: "breakfast" as Meal,
  calories: "",
  protein: "",
  carbs: "",
  fat: "",
};

function computeTotals(entries: FoodEntry[]): Totals {
  return entries.reduce<Totals>(
    (acc, entry) => ({
      calories: acc.calories + entry.calories,
      protein: acc.protein + entry.protein,
      carbs: acc.carbs + entry.carbs,
      fat: acc.fat + entry.fat,
    }),
    { calories: 0, protein: 0, carbs: 0, fat: 0 },
  );
}

export default function NutritionTracker() {
  const [entries, setEntries] = useState<FoodEntry[]>([]);
  const [form, setForm] = useState(EMPTY_FORM);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const totals = useMemo(() => computeTotals(entries), [entries]);

  async function loadEntries() {
    setLoading(true);
    try {
      const res = await fetch("/api/entries");
      if (!res.ok) throw new Error("Failed to load entries");
      const data = (await res.json()) as { entries: FoodEntry[] };
      setEntries(data.entries);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load entries");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadEntries();
  }, []);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!form.name.trim()) {
      setError("Food name is required");
      return;
    }
    setSubmitting(true);
    try {
      const res = await fetch("/api/entries", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: form.name,
          meal: form.meal,
          calories: Number(form.calories) || 0,
          protein: Number(form.protein) || 0,
          carbs: Number(form.carbs) || 0,
          fat: Number(form.fat) || 0,
        }),
      });
      if (!res.ok) {
        const data = (await res.json().catch(() => ({}))) as { error?: string };
        throw new Error(data.error ?? "Failed to add entry");
      }
      const data = (await res.json()) as { entry: FoodEntry };
      setEntries((prev) => [data.entry, ...prev]);
      setForm(EMPTY_FORM);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to add entry");
    } finally {
      setSubmitting(false);
    }
  }

  async function handleDelete(id: string) {
    const previous = entries;
    setEntries((prev) => prev.filter((entry) => entry.id !== id));
    try {
      const res = await fetch(`/api/entries/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error("Failed to delete entry");
    } catch (err) {
      setEntries(previous);
      setError(err instanceof Error ? err.message : "Failed to delete entry");
    }
  }

  return (
    <div className="flex flex-col gap-8">
      <TotalsCard totals={totals} count={entries.length} />

      <form
        onSubmit={handleSubmit}
        className="flex flex-col gap-4 rounded-xl border border-slate-200 bg-white p-5 shadow-sm dark:border-slate-800 dark:bg-slate-900"
      >
        <h2 className="text-lg font-semibold">Add food</h2>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <label className="flex flex-col gap-1 text-sm sm:col-span-2">
            <span className="font-medium">Food name</span>
            <input
              name="name"
              value={form.name}
              onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
              placeholder="e.g. Greek yogurt"
              className="rounded-lg border border-slate-300 bg-transparent px-3 py-2 outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/30 dark:border-slate-700"
            />
          </label>
          <label className="flex flex-col gap-1 text-sm">
            <span className="font-medium">Meal</span>
            <select
              name="meal"
              value={form.meal}
              onChange={(e) =>
                setForm((f) => ({ ...f, meal: e.target.value as Meal }))
              }
              className="rounded-lg border border-slate-300 bg-transparent px-3 py-2 capitalize outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/30 dark:border-slate-700"
            >
              {MEALS.map((meal) => (
                <option key={meal} value={meal} className="capitalize">
                  {meal}
                </option>
              ))}
            </select>
          </label>
          <NumberField
            label="Calories"
            name="calories"
            value={form.calories}
            onChange={(v) => setForm((f) => ({ ...f, calories: v }))}
          />
          <NumberField
            label="Protein (g)"
            name="protein"
            value={form.protein}
            onChange={(v) => setForm((f) => ({ ...f, protein: v }))}
          />
          <NumberField
            label="Carbs (g)"
            name="carbs"
            value={form.carbs}
            onChange={(v) => setForm((f) => ({ ...f, carbs: v }))}
          />
          <NumberField
            label="Fat (g)"
            name="fat"
            value={form.fat}
            onChange={(v) => setForm((f) => ({ ...f, fat: v }))}
          />
        </div>

        {error && (
          <p className="text-sm text-red-600 dark:text-red-400" role="alert">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={submitting}
          className="self-start rounded-lg bg-emerald-600 px-4 py-2 font-medium text-white transition hover:bg-emerald-700 disabled:cursor-not-allowed disabled:opacity-60"
        >
          {submitting ? "Adding..." : "Add entry"}
        </button>
      </form>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-semibold">Today&apos;s log</h2>
        {loading ? (
          <p className="text-sm text-slate-500">Loading entries...</p>
        ) : entries.length === 0 ? (
          <p className="rounded-lg border border-dashed border-slate-300 p-6 text-center text-sm text-slate-500 dark:border-slate-700">
            No entries yet. Add your first food above.
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {entries.map((entry) => (
              <li
                key={entry.id}
                className="flex items-center justify-between gap-4 rounded-lg border border-slate-200 bg-white px-4 py-3 dark:border-slate-800 dark:bg-slate-900"
              >
                <div className="flex flex-col">
                  <span className="font-medium">{entry.name}</span>
                  <span className="text-xs uppercase tracking-wide text-emerald-600 dark:text-emerald-400">
                    {entry.meal}
                  </span>
                </div>
                <div className="flex items-center gap-4">
                  <div className="text-right text-sm">
                    <div className="font-semibold">{entry.calories} kcal</div>
                    <div className="text-xs text-slate-500">
                      P {entry.protein}g · C {entry.carbs}g · F {entry.fat}g
                    </div>
                  </div>
                  <button
                    onClick={() => handleDelete(entry.id)}
                    aria-label={`Delete ${entry.name}`}
                    className="rounded-md px-2 py-1 text-sm text-slate-400 transition hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-950"
                  >
                    Delete
                  </button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function TotalsCard({ totals, count }: { totals: Totals; count: number }) {
  const items = [
    { label: "Calories", value: `${totals.calories}`, unit: "kcal" },
    { label: "Protein", value: totals.protein.toFixed(1), unit: "g" },
    { label: "Carbs", value: totals.carbs.toFixed(1), unit: "g" },
    { label: "Fat", value: totals.fat.toFixed(1), unit: "g" },
  ];
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
      {items.map((item) => (
        <div
          key={item.label}
          className="rounded-xl border border-slate-200 bg-white p-4 text-center shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div className="text-2xl font-bold text-emerald-600 dark:text-emerald-400">
            {item.value}
            <span className="ml-1 text-sm font-normal text-slate-400">
              {item.unit}
            </span>
          </div>
          <div className="text-xs uppercase tracking-wide text-slate-500">
            {item.label}
          </div>
        </div>
      ))}
      <p className="col-span-2 text-center text-xs text-slate-400 sm:col-span-4">
        {count} {count === 1 ? "entry" : "entries"} logged
      </p>
    </div>
  );
}

function NumberField({
  label,
  name,
  value,
  onChange,
}: {
  label: string;
  name: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="flex flex-col gap-1 text-sm">
      <span className="font-medium">{label}</span>
      <input
        type="number"
        inputMode="decimal"
        min={0}
        step="any"
        name={name}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder="0"
        className="rounded-lg border border-slate-300 bg-transparent px-3 py-2 outline-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-500/30 dark:border-slate-700"
      />
    </label>
  );
}
