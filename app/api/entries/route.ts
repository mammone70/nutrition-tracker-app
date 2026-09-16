import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { isMeal } from "@/lib/meals";

export const dynamic = "force-dynamic";

export async function GET() {
  const entries = await prisma.foodEntry.findMany({
    orderBy: { createdAt: "desc" },
  });
  return NextResponse.json({ entries });
}

function toNonNegativeNumber(value: unknown, fallback = 0): number {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) {
    return fallback;
  }
  return parsed;
}

export async function POST(request: Request) {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const data = (body ?? {}) as Record<string, unknown>;
  const name = typeof data.name === "string" ? data.name.trim() : "";

  if (!name) {
    return NextResponse.json({ error: "Food name is required" }, { status: 400 });
  }

  const meal = isMeal(data.meal) ? data.meal : "breakfast";

  const entry = await prisma.foodEntry.create({
    data: {
      name,
      meal,
      calories: Math.round(toNonNegativeNumber(data.calories)),
      protein: toNonNegativeNumber(data.protein),
      carbs: toNonNegativeNumber(data.carbs),
      fat: toNonNegativeNumber(data.fat),
    },
  });

  return NextResponse.json({ entry }, { status: 201 });
}
