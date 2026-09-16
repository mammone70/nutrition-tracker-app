import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const count = await prisma.foodEntry.count();
  if (count > 0) {
    console.log(`Seed skipped: ${count} entries already exist.`);
    return;
  }

  await prisma.foodEntry.createMany({
    data: [
      {
        name: "Oatmeal with banana",
        meal: "breakfast",
        calories: 350,
        protein: 10,
        carbs: 60,
        fat: 6,
      },
      {
        name: "Grilled chicken salad",
        meal: "lunch",
        calories: 420,
        protein: 40,
        carbs: 18,
        fat: 20,
      },
    ],
  });

  console.log("Seeded 2 sample food entries.");
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
