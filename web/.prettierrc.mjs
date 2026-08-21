// carp24 Prettier-Config (BAUPLAN 0.13)
export default {
  plugins: ["prettier-plugin-astro"],
  semi: true,
  singleQuote: false,
  printWidth: 100,
  overrides: [
    {
      files: "*.astro",
      options: { parser: "astro" },
    },
  ],
};
